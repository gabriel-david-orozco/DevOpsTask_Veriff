#!/bin/bash
aws eks update-cluster-config \
    --region us-east-1 \
    --name Veriff-juice-shop \
    --resources-vpc-config endpointPublicAccess=true,publicAccessCidrs="83.51.133.0/24",endpointPrivateAccess=true
