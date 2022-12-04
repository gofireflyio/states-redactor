#!/usr/bin/env bash

if [ "$#" -ne 3 ] && [ "$#" -ne 4 ] && [ "$#" -ne 5 ]
  then
    echo "Usage: $0 provider os arch [by] [version]" >&2
    echo "For local run you should download darwin amd64" >&2
    echo "For docker you should download linux amd64" >&2
    exit 1
fi

provider="$1"
os="$2"
arch="$3"
if [ -z "$4" ]
  then
    by="hashicorp"
  else
    by="$4"
fi

if [ -z "$5" ]
  then
    version="latest"
  else
    version="$5"
fi

if [ "$version" = "latest" ]
  then
    version=$(curl "https://registry.terraform.io/v1/providers/${by}/${provider}/versions" | jq -r ".versions" | jq -r "sort_by(.version | split(\".\") | map(tonumber)) | reverse | first | .version")
fi

echo "Downloading ${provider} ${arch} ${version} terraform."

if [ "$os" = "darwin" ]
  then
    providers_folder="local_run_providers"
  else
    providers_folder="providers"
fi

mkdir "${providers_folder}"
mkdir "tmp"
cd "tmp"

curl "https://releases.hashicorp.com/terraform-provider-${provider}/${version}/terraform-provider-${provider}_${version}_${os}_${arch}.zip" > "${provider}.zip"
unzip -o "${provider}.zip" -d .
rm -f "${provider}.zip"
mv "terraform-provider-${provider}_v${version}"* "../${providers_folder}/${provider}"
chmod 777 "../${providers_folder}/${provider}"
