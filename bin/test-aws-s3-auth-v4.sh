#!/bin/bash

#############################################
# AWS S3 Authentication V4 Test Bash Script #
#############################################

###########
# Purpose:
# to test s3 access from a node.

#########
# Usage:
# file="" ./aws_s3.sh <AWS Key>

#########
# Options:
# file, bucket, gateway, body, region, and resource can be passed in as environment variables.

file="${file=public/deeplink.json}"
bucket="${bucket=exxon-dev-assets-cargohold-vc9ayndi}"
gateway="${gateway=s3-eu-central-1.amazonaws.com}"
body="${body=''}"
region="${region=eu-central-1}"

resource="${resource=${file}}"

s3Key="$1"

echo "enter the S3 secret coresponding to key ${s3Key}:"
read s3Secret

amzDateValue="`date -u +'%Y%m%dT%H%M%SZ' | tr -d $'\n'`"
amzDateSubValue="`echo $amzDateValue | sed 's/T.*//' | tr -d $'\n'`"

# values to verify results against: https://czak.pl/2015/09/15/s3-rest-api-with-curl.html
#bucket=my-precious-bucket
#gateway=s3.amazonaws.com
#region="us-east-1"
#resource=""
#s3Secret="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
#s3Key="AKIAIOSFODNN7EXAMPLE"
#amzDateValue="20150915T124500Z"
#amzDateSubValue="20150915"
#body=""

bodySHA256="`echo -en $body | sha256sum | sed 's/ .*//' | tr -d $'\n'`"
canonicalRequest="GET
/$resource

host:${bucket}.${gateway}
x-amz-content-sha256:${bodySHA256}
x-amz-date:${amzDateValue}

host;x-amz-content-sha256;x-amz-date
${bodySHA256}"

canonicalRequestSHA256=`echo -en "$canonicalRequest" | openssl dgst -sha256 | sed 's/^.* //'`

stringToSign="AWS4-HMAC-SHA256
${amzDateValue}
${amzDateSubValue}/${region}/s3/aws4_request
${canonicalRequestSHA256}"

dateKey=`echo -en "${amzDateSubValue}" | openssl dgst -sha256 -mac HMAC -macopt "key:AWS4${s3Secret}" | sed 's/^.* //'`
dateRegionKey=`echo -en "${region}" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${dateKey}" | sed 's/^.* //'`
dateRegionServiceKey=`echo -en "s3" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${dateRegionKey}" | sed 's/^.* //'`
signingKey=`echo -en "aws4_request" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${dateRegionServiceKey}" | sed 's/^.* //'`

signature=`/bin/echo -en "${stringToSign}" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${signingKey}" | sed 's/^.* //'`

curl -v https://${bucket}.${gateway}/${resource} \
     -H "Authorization: AWS4-HMAC-SHA256 \
         Credential=${s3Key}/${amzDateSubValue}/${region}/s3/aws4_request, \
         SignedHeaders=host;x-amz-content-sha256;x-amz-date, \
         Signature=${signature}" \
     -H "x-amz-content-sha256: ${bodySHA256}" \
     -H "x-amz-date: ${amzDateValue}"
