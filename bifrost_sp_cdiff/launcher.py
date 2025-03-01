#!/usr/bin/env python3
"""
Launcher file
"""
import argparse
import os
import sys
import traceback
from bifrostlib import common
from bifrostlib.datahandling import SampleReference
from bifrostlib.datahandling import Sample
from bifrostlib import datahandling
from bifrostlib.datahandling import Component
from bifrostlib.datahandling import ComponentReference
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent

import yaml
import pprint
from typing import List, Dict
#import snakemake
import subprocess

from contextlib import contextmanager


global COMPONENT

@contextmanager
def pushd(new_dir):
    """Context manager to change directory and restore it afterwards."""
    prev_dir = os.getcwd()  # Save the current working directory
    os.chdir(new_dir)       # Change to the new directory
    try:
        yield
    finally:
        os.chdir(prev_dir)  # Restore the previous working directory

def initialize():
    with open(os.path.join(os.path.dirname(__file__), 'config.yaml')) as fh:
        config: Dict = yaml.load(fh, Loader=yaml.FullLoader)

    if not(datahandling.has_a_database_connection()):
        raise ConnectionError("BIFROST_DB_KEY is not set or other connection error")

    global COMPONENT
    try:
        component_ref = ComponentReference(name=config["name"])
        COMPONENT = Component.load(component_ref)
        if COMPONENT is not None and '_id' in COMPONENT.json:
                return
        else:
            COMPONENT = Component(value=config)
            install_component()

    except Exception as e:
        print(traceback.format_exc(), file=sys.stderr)
    return


def install_component():
    COMPONENT['install']['path'] = os.path.os.getcwd()
    print(f"Installing with path:{COMPONENT['install']['path']}")
    try:
        COMPONENT.save()
        print(f"Done installing")
    except:
        print(traceback.format_exc(), file=sys.stderr)
        sys.exit(0)


class types():
    def file(path):
        if os.path.isfile(path):
            return os.path.abspath(path)
        else:
            raise argparse.ArgumentTypeError(f"{path} #Bad file path")

    def directory(path):
        if os.path.isdir(path):
            return os.path.abspath(path)
        else:
            raise argparse.ArgumentTypeError(f"{path} #Bad directory path")


def parse_and_run(args: List[str]) -> None:
    description: str = (
        f"-Description------------------------------------\n"
        f"{COMPONENT['details']['description']}"
        f"------------------------------------------------\n"
        f"\n"
        f"-Environmental Variables/Defaults---------------\n"
        f"BIFROST_CONFIG_DIR: {os.environ.get('BIFROST_CONFIG_DIR','.')}\n"
        f"BIFROST_RUN_DIR: {os.environ.get('BIFROST_RUN_DIR','.')}\n"
        f"------------------------------------------------\n"
        f"\n"
    )

    # Using two parsers for UX so that install doesn't conflict while all the args still point to the main parser
    basic_parser = argparse.ArgumentParser(add_help=False)
    basic_parser.add_argument(
        '--reinstall',
        action='store_true',
    )
    basic_parser.add_argument(
        '--info',
        action='store_true',
        help='Provides basic information on COMPONENT'
    )

    #Second parser for the arguements related to the program, everything can be set to defaults (or has defaults)
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description=description,
                                                              formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        '--debug',
        action='store_true',
        help='Show arg values'
    )
    parser.add_argument(
        '-out', '--outdir',
        default=os.environ.get('BIFROST_RUN_DIR', os.getcwd()),
        help='Output directory'
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '-name', '--sample_name',
        action='store',
        type=str,
        help='Sample name of sample in bifrost, sample has already been added to the bifrost DB'
    )
    group.add_argument(
        '-id', '--sample_id',
        action='store',
        type=str,
        help='Sample ID of sample in bifrost, sample has already been added to the bifrost DB'
    )

    try:
        basic_options, extras = basic_parser.parse_known_args(args)
        if basic_options.reinstall:
            install_component()
            return None
        elif basic_options.info:
            show_info()
            return None
        else:
            pipeline_options, junk = parser.parse_known_args(extras)
            if pipeline_options.debug is True:
                print(pipeline_options)
            run_pipeline(pipeline_options)
    except Exception as e:
        raise

def show_info() -> None:
    pprint.pprint(COMPONENT.json)

def subprocess_runner(snakefile,
                      config, outdir,
                      cores= os.cpu_count):
        config_list = ["--config"] + [f"{k}={v}" for k,v in config.items()]
        command = ["snakemake","-p","--nolock","--cores", "all",
                   "-s", snakefile ]
        command.extend(config_list)
        print(" ".join(command))
        process: subprocess.Popen = subprocess.Popen(
            command,
            stdout=sys.stdout,
            stderr=sys.stderr,
            shell=False,
            cwd=outdir
        )
        process.communicate()
        if process.returncode != 0:
            raise RuntimeError(f"Command {' '.join([str(x) for x in command])} failed with code {process.returncode}")

def run_pipeline(args: argparse.Namespace, runner=subprocess_runner) -> None:
    try:
        config = {"component_name": COMPONENT['name']}
        if args.sample_id is not None:
            config["sample_id"] = args.sample_id
            sample_ref = SampleReference(_id=args.sample_id)
        else:
            config["sample_name"]=args.sample_name
            sample_ref = SampleReference(name=args.sample_name)
        sample:Sample = Sample.load(sample_ref) # schema 2.1
        samplecomponent_ref = SampleComponentReference(name=SampleComponentReference.name_generator(sample.to_reference(), COMPONENT.to_reference()))
        samplecomponent = SampleComponent.load(samplecomponent_ref)
        if samplecomponent is None:
            samplecomponent:SampleComponent = SampleComponent(sample_reference=sample.to_reference(), component_reference=COMPONENT.to_reference()) # schema 2.1

        snakefile = os.path.join(os.path.dirname(__file__),'pipeline.smk')
        with pushd(args.outdir):
            status = runner(
                snakefile=snakefile,
                config=config,
                outdir=args.outdir,
                cores = os.cpu_count
            )
    except Exception:
        common.set_status_and_save(sample, samplecomponent, "Failure")
        print(traceback.format_exc())
        raise

def main(args = sys.argv):
    initialize()
    parse_and_run(args)


if __name__ == '__main__':
    main()
