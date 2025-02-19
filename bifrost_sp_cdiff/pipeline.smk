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
    print(f"sample_ref {sample_ref} and sample id {sample_id}")
    if sample is None:
        raise Exception("invalid sample passed")
    component_ref = ComponentReference(name=config['component_name'])
    component:Component = Component.load(reference=component_ref) # schema 2.1
    if component is None:
        raise Exception("invalid component passed")
    samplecomponent_ref = SampleComponentReference(name=SampleComponentReference.name_generator(sample.to_reference(), component.to_reference()))
    samplecomponent = SampleComponent.load(samplecomponent_ref)
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
    params:
        samplecomponent
    run:
        if samplecomponent.has_requirements():
            with open(output.check_file, "w") as fh:
                fh.write("")

#- Templated section: end --------------------------------------------------------------------------

#* Dynamic section: start **************************************************************************
rule_name = "run_cdifftyping"
rule run_cdifftyping:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark",
    input:  # files
        rules.check_requirements.output.check_file,
        reads = sample['categories']['paired_reads']['summary']['data'],
        assembly = sample['categories']['contigs']['summary']['data'],
        db = f"{resources_dir}/bifrost_sp_cdiff/{component['resources']['db']}",
    params:  # values
        sample_id = sample_id,
        update = "no",
    output:
        _R1 = f"{rules.setup.params.folder}/sp_cdiff_fbi/cdifffiltered_R1.fastq",
        _R2 = f"{rules.setup.params.folder}/sp_cdiff_fbi/cdifffiltered_R2.fastq",
        _bam = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.bam",
        _bai = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.bam.bai",
        _cdtA = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}_cdtA.info",
        _cdtB = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}_cdtB.info",
        _tcdA = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}_tcdA.info",
        _tcdB = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}_tcdB.info",
        _tcdC = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}_tcdC.info",
        _coverage = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage",
        _counts = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage.sample_cumulative_coverage_counts",
        _proportions = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage.sample_cumulative_coverage_proportions",
        _interval_statistics = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage.sample_interval_statistics",
        _interval_summary = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage.sample_interval_summary",
        _sample_statistics = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage.sample_statistics",
        _sample_summary = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.coverage.sample_summary",
        _indel_vcf = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.indel.vcf",
        _indel_vcf_idx = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.indel.vcf.idx",
        _sam = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.sam",
        _snp_indel_vcf = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.snp_indel.vcf",
        _snp_indel_vcf_idx = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.snp_indel.vcf.idx",
        _snp_vcf = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.snp.vcf",
        _snp_vcf_idx = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}.snp.vcf.idx",
        _TRST_fasta = f"{rules.setup.params.folder}/sp_cdiff_fbi/{sample_id}_TRST.fasta",
    shell:
        """
        #Type
        bash {resources_dir}/bifrost_sp_cdiff/cdiff_fbi/cdifftyping.sh -i {params.sample_id} -R1 {input.reads[0]} -R2 {input.reads[1]} -c {input.assembly} -o {output.folder} -db {input.db} -update {params.update} 1> {log.out_file} 2> {log.err_file}
        """

rule_name = "run_postcdifftyping"
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
        _R1 = rules.run_cdifftyping.output._R1,
        _R2 = rules.run_cdifftyping.output._R2,
        _bam = rules.run_cdifftyping.output._bam,
        _bai = rules.run_cdifftyping.output._bai,
        _cdtA = rules.run_cdifftyping.output._cdtA,
        _cdtB = rules.run_cdifftyping.output._cdtB,
        _tcdA = rules.run_cdifftyping.output._tcdA,
        _tcdB = rules.run_cdifftyping.output._tcdB,
        _tcdC = rules.run_cdifftyping.output._tcdC,
        _coverage = rules.run_cdifftyping.output._coverage,
        _counts = rules.run_cdifftyping.output._counts,
        _proportions = rules.run_cdifftyping.output._proportions,
        _interval_statistics = rules.run_cdifftyping.output._interval_statistics,
        _interval_summary = rules.run_cdifftyping.output._interval_summary,
        _sample_statistics = rules.run_cdifftyping.output._sample_statistics,
        _sample_summary = rules.run_cdifftyping.output._sample_summary,
        _indel_vcf = rules.run_cdifftyping.output._indel_vcf,
        _indel_vcf_idx = rules.run_cdifftyping.output._indel_vcf_idx,
        _sam = rules.run_cdifftyping.output._sam,
        _snp_indel_vcf = rules.run_cdifftyping.output._snp_indel_vcf,
        _snp_indel_vcf_idx = rules.run_cdifftyping.output._snp_indel_vcf_idx,
        _snp_vcf = rules.run_cdifftyping.output._snp_vcf,
        _snp_vcf_idx = rules.run_cdifftyping.output._snp_vcf_idx,
        _TRST_fasta = rules.run_cdifftyping.output._TRST_fasta,
    params:  # values
        sample_id = rules.run_cdifftyping.params.sample_id,
    output:
        _file = f"{rules.run_cdifftyping.output.folder}/{rules.run_cdifftyping.params.sample_id}.json",
        _csv = f"{rules.run_cdifftyping.output.folder}/{rules.run_cdifftyping.params.sample_id}.csv",
    shell:
        """
        # Process
        bash {resources_dir}/bifrost_sp_cdiff/cdiff_fbi/postcdifftyping.sh -i {params.sample_id} -d {input.folder} -stbit "STNA;NA:NA" 1> {log.out_file} 2> {log.err_file}
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
#- Templated section: end --------------------------------------------------------------------------