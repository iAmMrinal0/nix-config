{ pkgs, ... }: {
  services.home-manager = {
    autoExpire = {
      frequency = "daily";
      store.cleanup = true;
      store.options = "--delete-older-than 30d";
    };
  };
}
