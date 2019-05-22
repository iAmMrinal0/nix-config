{pkgs, ...}:

{
  enable = true;
  enableCompletion = true;
  defaultKeymap = "emacs";
  history.expireDuplicatesFirst = true;
  history.extended = true;
  oh-my-zsh = {
    enable = true;
    plugins = ["git" "sudo" "extract"];
    theme = "mod_steeef";
    custom = "\$HOME/.oh-my-zsh/custom";
  };
  plugins = [
    {
      name = "zsh-autosuggestions";
      src = pkgs.fetchFromGitHub {
      owner = "zsh-users";
      repo = "zsh-autosuggestions";
      rev = "v0.5.2";
      sha256 = "1xhrdv6cgmq9qslb476rcs8ifw8i2vf43yvmmscjcmpz0jac4sbx";
      };
    }
  ];
}
