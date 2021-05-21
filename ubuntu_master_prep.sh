#!/bin/bash

sudo systemctl enable kubelet

sudo kubeadm config images pull

