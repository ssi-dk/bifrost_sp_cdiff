#- Templated section: start ------------------------------------------------------------------------
import os
import sys
import traceback

from bifrostlib import common
from bifrostlib.datahandling import SampleReference
from bifrostlib.datahandling import Sample
from bifrostlib.datahandling import ComponentReference
from bifrostlib.datahandling import Component
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
os.umask(0o2)

try:
    sample_ref = SampleReference(_id=config.get('sample_id', None), name=config.get('sample_name', None))
    sample:Sample = Sample.load(sample_ref) # schema 2.1
    sample_id=sample['name']
    #print(f"sample_ref {sample_ref} and sample id {sample_id}")
    if sample is None:
        raise Exception("invalid sample passed")
    component_ref = ComponentReference(name=config['component_name'])
    component:Component = Component.load(reference=component_ref) # schema 2.1
    #print(f"Component ref: {component_ref}")
    #print(f"Component ref: {component}")
    if component is None:
        raise Exception("invalid component passed")
    samplecomponent_ref = SampleComponentReference(name=SampleComponentReference.name_generator(sample.to_reference(), component.to_reference()))
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    #print(f"sample component_ref {samplecomponent_ref}")
    #print(f"sample component {samplecomponent}")
    if samplecomponent is None:
        samplecomponent:SampleComponent = SampleComponent(sample_reference=sample.to_reference(), component_reference=component.to_reference()) # schema 2.1
    common.set_status_and_save(sample, samplecomponent, "Running")

except Exception as error:
    print(traceback.format_exc(), file=sys.stderr)
    raise Exception("failed to set sample, component and/or samplecomponent")

onerror:
    if not samplecomponent.has_requirements():
        common.set_status_and_save(sample, samplecomponent, "Requirements not met")
    if samplecomponent['status'] == "Running":
        common.set_status_and_save(sample, samplecomponent, "Failure")

envvars:
    "BIFROST_INSTALL_DIR",
    "CONDA_PREFIX"

resources_dir=f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}"

rule all:
    input:
        f"{component['name']}/datadump_complete"
    run:
        common.set_status_and_save(sample, samplecomponent, "Success")

rule setup:
    output:
        init_file = touch(temp(f"{component['name']}/initialized")),
    params:
        folder = component['name']
    run:
        samplecomponent['path'] = os.path.join(os.getcwd(), component['name'])
        samplecomponent.save()


rule_name = "check_requirements"
rule check_requirements:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        folder = rules.setup.output.init_file,
    output:
        check_file = f"{component['name']}/requirements_met",
    run:
        if samplecomponent.has_requirements():
            with open(output.check_file, "w") as fh:
                fh.write("")

#- Templated section: end --------------------------------------------------------------------------

#* Dynamic section: start **************************************************************************
def generate_cdifftyping_files(sample_id):
    return [
        f"cdifffiltered_R1.fastq", 
        f"cdifffiltered_R2.fastq",
        f"{sample_id}.bam", 
        f"{sample_id}.bam.bai",
        f"{sample_id}_cdtA.info", 
        f"{sample_id}_cdtB.info",
        f"{sample_id}_tcdA.info", 
        f"{sample_id}_tcdB.info", 
        f"{sample_id}_tcdC.info",
        f"{sample_id}.coverage",
        f"{sample_id}.coverage.sample_cumulative_coverage_counts",
        f"{sample_id}.coverage.sample_cumulative_coverage_proportions",
        f"{sample_id}.coverage.sample_interval_statistics",
        f"{sample_id}.coverage.sample_interval_summary",
        f"{sample_id}.coverage.sample_statistics",
        f"{sample_id}.coverage.sample_summary",
        f"{sample_id}.indel.vcf", 
        f"{sample_id}.indel.vcf.idx",
        f"{sample_id}.sam",
        f"{sample_id}.snp_indel.vcf", 
        f"{sample_id}.snp_indel.vcf.idx",
        f"{sample_id}.snp.vcf", 
        f"{sample_id}.snp.vcf.idx",
        f"{sample_id}_TRST.fasta"
    ]

rule_name_typing = "run_cdifftyping"

cdifftyping_out_dir=f"{rules.setup.params.folder}/{rule_name_typing}/{sample_id}/sp_cdiff_fbi"

rule run_cdifftyping:
    message:
        f"Running step:{rule_name_typing}"
    log:
        out_file = f"{component['name']}/log/{rule_name_typing}.out.log",
        err_file = f"{component['name']}/log/{rule_name_typing}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name_typing}.benchmark",
    input:  # files
        rules.check_requirements.output.check_file,
        reads = sample['categories']['paired_reads']['summary']['data'],
        assembly = sample['categories']['contigs']['summary']['data'],
        db = f"{resources_dir}/bifrost_sp_cdiff/{component['resources']['db']}",
    output:
        expand(f"{cdifftyping_out_dir}/{{filename}}", filename=generate_cdifftyping_files(sample_id)),
    shell:
        """
        #Type
        bash {resources_dir}/bifrost_sp_cdiff/cdiff_fbi/cdifftyping.sh -i {sample_id} -R1 {input.reads[0]} -R2 {input.reads[1]} -c {input.assembly} -o {rules.setup.params.folder}/{rule_name_typing} -db {input.db} -update no 1> {log.out_file} 2> {log.err_file}
        """

rule_name = "run_postcdifftyping"

postcdifftyping_out_dir=f"{rules.setup.params.folder}/{rule_name_typing}/{sample_id}"

rule run_postcdifftyping:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark",
    input:  # files
        rules.check_requirements.output.check_file,
        expand(f"{cdifftyping_out_dir}/{{filename}}", filename=generate_cdifftyping_files(sample_id)),
    output:
        _file = f"{postcdifftyping_out_dir}/{sample_id}.json",
        _csv = f"{postcdifftyping_out_dir}/{sample_id}.csv",
    shell:
        """
        # Process
        bash {resources_dir}/bifrost_sp_cdiff/cdiff_fbi/postcdifftyping.sh -i {sample_id} -d {rules.setup.params.folder}/{rule_name_typing} -stbit "STNA;NA:NA" 1> {log.out_file} 2> {log.err_file}
        """
#* Dynamic section: end ****************************************************************************

#- Templated section: start ------------------------------------------------------------------------
rule_name = "datadump"
rule datadump:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        cdiff_analysis_output_file = rules.run_postcdifftyping.output._file,
        cdiff_analysis_output_csv = rules.run_postcdifftyping.output._csv,
    output:
        complete = rules.all.input
    params:
        samplecomponent_ref_json = samplecomponent.to_reference().json
    script:
        f"{resources_dir}/bifrost_sp_cdiff/datadump.py"
#- Templated section: end -------------------------------------------------------------------------