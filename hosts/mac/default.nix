{
  imports = [ ./node.nix ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;

  # Determinate Nix manages the Nix installation, the daemon and /etc/nix/nix.conf.
  nix.enable = false;

  # The shell startup files in /etc keep the Nix setup the installer wrote.
  programs.zsh.enable = false;
  programs.bash.enable = false;
}
