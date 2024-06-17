# bifrost_sp_cdiff
This component runs given a sample_id already added into the bifrostDB. If the sample is registered as *Clostridiodes difficile*, it should pull the paired reads, the contigs, and do the typing according to [cdiff_fbi](https://github.com/ssi-dk/cdiff_fbi)

## How to launch
```bash
git clone https://github.com/ssi-dk/bifrost_sp_cdiff.git
cd bifrost_sp_cdiff
bash install.sh -i LOCAL
conda activate bifrost_sp_cdiff_vx.x.x
export BIFROST_INSTALL_DIR='/your/path/'
BIFROST_DB_KEY="/your/key/here/" python -m bifrost_sp_cdiff -h
```
