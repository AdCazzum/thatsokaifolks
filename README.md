# That's OK-AI

This is the repository for a blockchain-based software that uses:

1. https://www.fluence.network/ decentralized compute-as-a-service
2. https://www.walrus.xyz/ for storage
3. https://flare.network/ to provide traceability of inputs and outputs

The purpose of this software is to provide a ready-to-use virtual compute image
that can be use to perform distributed training of machine learning models, with
blockchain backed verification of source data and produced models.

The repository is a Work-in-Progress and it's not ready to be used, yet.
We are going to build the application using AI agents to aid the development.
The process will be done in steps.

The first step is to produce a .raw or .qcow2 which contains the base image for
the distributed training. The images will be created using NixOS, so it will be
easy to reproduce, modify and generate the image files.
[NixOS generators](https://github.com/nix-community/nixos-generators) might
provide a way to easily turn system configurations into usable images.
The first step is therefore to have an environment to produce such images. The
content of the image is irrelevant and a basic funcioning image is sufficient.

In the second step, we'll integrate some distributed-training tooling, framework
or, in general, resources that can be used to perform distributed training.
Here, it's useful to have an example application of distributed training to
provide a demo.

In the third step, we'll use walrus to source the data: somewhere in the walrus
network there will be input data ready to be used, therefore we'll have to
prepare the image so that it will access the data and use it for training.
The output of this step is to have a model trained on data coming from walrus.

Finally, in the fourth step, we'll use flare smart contract for data provenance,
so that for each model we'll be sure about what image and what data have been
used to train the model.
The output will be a system (I don't know in what form, yet) that verifies this
connection between input and output. Possibly a web3 application that does so.
