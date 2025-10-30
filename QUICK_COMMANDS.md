# Quick Command Reference

## Expand Volume (One-Time Setup)

```bash
cd terraform
terraform apply -target=null_resource.expand_root_volume
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
sudo growpart /dev/nvme0n1 1 && sudo resize2fs /dev/nvme0n1p1 && df -h
```

## Run Extractor

```bash
cd terraform
./run_extractor.sh
```

## Deploy Dictionaries

```bash
cd terraform
./deploy_dictionaries.sh
```

## Instance Control

```bash
cd terraform
./start_stop.sh start   # Start instance
./start_stop.sh stop    # Stop instance
./start_stop.sh status  # Check status
```

## SSH Access

```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
```

## Check Results

```bash
# Local results
ls -lh terraform/extractor-results/*/

# On EC2
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
cd ~/ido-esperanto-extractor
ls -lh dist/
cat reports/stats_summary.md
```

## Verify Dictionary Counts

```bash
# On EC2
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
cd ~/ido-esperanto-extractor

# Check entry counts
python3 -c "import json; print('Ido:', len(json.load(open('dist/ido_dictionary.json'))))"
python3 -c "import json; print('Bidix:', len(json.load(open('dist/bidix_big.json'))))"
python3 -c "import json; v=json.load(open('dist/vortaro_dictionary.json')); print('Vortaro:', v['metadata']['total_words'])"
```

## Clean Up Space

```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
cd ~/ido-esperanto-extractor
rm -rf work/*.json data/raw/*.xml.bz2
df -h
```
