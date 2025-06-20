{ config, pkgs, lib, ... }:

{
  options = { };

  config = { programs.jq.enable = true; };
}
