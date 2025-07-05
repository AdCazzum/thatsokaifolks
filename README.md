# That's OK-AI

This is the repository for a blockchain-based host configuration to perform
model training automatically.

This uses:

1. https://www.fluence.network/ decentralized compute-as-a-service
2. https://www.walrus.xyz/ for storage (input data and model output)
3. https://flare.network/ to provide traceability of inputs and outputs

The purpose of this software is to provide a easy-to-make virtual compute image
that can be use to perform distributed training of machine learning models, with
blockchain backed verification of source data and produced models.

## Development

The development is done in steps.

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

## Usage

This repo is self-container to get an up-and-running image, but it's using
test networks. To use this, you need a fluence account and a public-facing host
with nix or nixos on it (with port 8080 open to the world).

1. enter your nix host (e.g. `foo.example.com`) and clone this repository;
2. customize the files according to your needs:
   - `configuration.nix`: with your users, ssh keys, programs, settings and so on;
   - `walrus-puller.nix`: to pull your training data
   - `model-trainer.nix`: to train your model
   - `walrus-pusher.nix`: to push your output model
3. build the image using `nix build`, this produces a `./result` directory with
   your image file (e.g. `nixos-image-kubevirt-25.11.20250630.3016b4b-x86_64-linux.qcow2`)
4. start a web server to serve the image
5. from fluence console, remember to specify the url of your image, say
   `https://foo.example.com/images/nixos-image-kubevirt-25.11.20250630.3016b4b-x86_64-linux.qcow2`
   before starting the machine. At the time of writing, fluence **does not**
   insert your ssh keys from the control panel when using a custom image, so
   you will need to set them in your `configuration.nix` or set a password.

In this repo, there are some more things that are useful for the demo:

1. a Telegram bot script that can be used to collect notifications via HTTP POST;
   to run it, register a bot using Botfather, get a key and run it using
   something like:
   ```bash
   WEBHOOK_PORT=8888 TELEGRAM_BOT_TOKEN=... python3 telegram_notifier_bot.py
   ```
2. a `Caddyfile` that is used to work as reverse-proxy for the telegram bot and
   to serve the files in `./result`:
   ```bash
   # Build the image
   nix build

   # ./result contains the nixos.qcow2 file, serve it and route notifications
   caddy run --config Caddyfile
   ```
