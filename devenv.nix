{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.nixos-generators
    # pkgs.qemu
  ];

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  scripts.build-vm.exec = "nixos-generate -f qcow -c configuration.nix";
  scripts.run-vm.exec = ''
    if [ $# -eq 0 ]; then
      echo "Usage: run-vm <path-to-qcow2-file>"
      exit 1
    fi

    QCOW2_FILE="$1"

    if [ ! -f "$QCOW2_FILE" ]; then
      echo "Error: File '$QCOW2_FILE' not found"
      exit 1
    fi

    echo "Starting QEMU VM with $QCOW2_FILE"
    echo "VM Configuration: 4GB RAM, 5GB disk"

    qemu-system-x86_64 \
      -m 4G \
      -hda "$QCOW2_FILE" \
      -enable-kvm \
      -cpu host \
      -smp 2 \
      -netdev user,id=net0 \
      -device virtio-net-pci,netdev=net0 \
      -display gtk
  '';

  enterShell = ''
    hello
    git --version
    echo "nixos-generate available: $(which nixos-generate)"
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
