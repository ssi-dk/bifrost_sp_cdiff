#!/usr/bin/env python3
import os
from typing import Dict
from pprint import pprint
import json


from bifrostlib import common
from bifrostlib.datahandling import (Category, Component, Sample,
                                     SampleComponent, SampleComponentReference)


def extract_results_from_json(toxin_profile: Category, results: Dict, component_name: str, file_name: str) -> None:
    with open(file_name) as fd:
        results = json.load(fd)
    toxin_profile["summary"] = results


def datadump(input: object, output: object, samplecomponent_ref_json: Dict):
    samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    sample = Sample.load(samplecomponent.sample)
    component = Component.load(samplecomponent.component)
    
    toxin_profile = sample.get_category("toxin_profile")
    if toxin_profile is None:
        toxin_profile = Category(value={
            "name": "bifrost_sp_cdiff",
            "component": samplecomponent.component,
            "summary": {
                "cdiff_fbi": "",
            },
            "report": {}
        })
    extract_results_from_json(
        toxin_profile,
        samplecomponent["results"],
        samplecomponent["component"]["name"],
        input.cdiff_analysis_output_file)
    
    samplecomponent.set_category(toxin_profile)
    sample.set_category(toxin_profile)
    samplecomponent.save_files()
    common.set_status_and_save(sample, samplecomponent, "Success")
    pprint(output.complete)
    with open(output.complete[0], "w+") as fh:
        fh.write("done")


datadump(
    snakemake.input,
    snakemake.output,
    snakemake.params.samplecomponent_ref_json,
)
