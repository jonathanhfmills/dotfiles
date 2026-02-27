{ pkgs, lib, ... }:

{
  home.username = "jon";
  home.homeDirectory = "/home/jon";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    settings.user.name = "Jonathan Mills";
    settings.user.email = "";
    settings.gpg.ssh.program = "${pkgs._1password-gui}/share/1password/op-ssh-sign";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = "~/.1password/agent.sock";
        };
      };
      # Fleet hosts.
      "desktop" = {
        hostname = "100.74.117.36";
        user = "jon";
      };
      "nas" = {
        hostname = "100.87.216.16";
        user = "jon";
      };
      "portable" = {
        hostname = "portable";
        user = "jon";
      };
      "workstation" = {
        hostname = "100.95.201.10";
        user = "jon";
      };
      # Client sites.
      "alohajays.com" = {
        hostname = "35.236.219.140";
        user = "alohajays";
        port = 37783;
      };
      "animalkingdomaz.com" = {
        hostname = "35.236.219.140";
        user = "animalkingdomaz";
        port = 16922;
      };
      "callahandrivingschool.com" = {
        hostname = "35.236.219.140";
        user = "callahandrivingschool";
        port = 49043;
      };
      "charlottedogclub.com" = {
        hostname = "35.236.219.140";
        user = "charlottedogclub";
        port = 25764;
      };
      "charlottedogclub.com-staging" = {
        hostname = "35.236.219.140";
        user = "charlottedogclub";
        port = 65159;
      };
      "dreamtailssarasota.com" = {
        hostname = "35.224.70.159";
        user = "dreamtails";
        port = 59121;
      };
      "furrybabiespuppies.com" = {
        hostname = "35.236.219.140";
        user = "furrybabiespuppies";
        port = 33263;
      };
      "georgiadogclub.com" = {
        hostname = "35.236.219.140";
        user = "georgiadogclub";
        port = 47477;
      };
      "haven-house.com" = {
        hostname = "35.236.219.140";
        user = "havenhouse";
        port = 42146;
      };
      "houstonpetland.com" = {
        hostname = "35.236.219.140";
        user = "houstonpetland";
        port = 27817;
      };
      "integritypoolservice.com" = {
        hostname = "35.236.219.140";
        user = "integritypoolservice";
        port = 55701;
      };
      "iseamedia.com" = {
        hostname = "35.236.219.140";
        user = "iseamedia";
        port = 32878;
      };
      "jaxpetland.com" = {
        hostname = "35.236.219.140";
        user = "petlandjacksonville";
        port = 17421;
      };
      "laslokitchens.com" = {
        hostname = "35.236.219.140";
        user = "laslokitchens";
        port = 58363;
      };
      "lehighgap.com" = {
        hostname = "35.236.219.140";
        user = "lehighgap";
        port = 17810;
      };
      "lensrxlab.com" = {
        hostname = "35.236.219.140";
        user = "lensrxlabs";
        port = 62015;
      };
      "lrwfarm.com" = {
        hostname = "35.224.70.159";
        user = "littleredwagona";
        port = 58434;
      };
      "muchlovejandk.com" = {
        hostname = "35.236.219.140";
        user = "muchlove";
        port = 25950;
      };
      "permaflowgutterprotection.com" = {
        hostname = "35.236.219.140";
        user = "permaflowgutterprotection";
        port = 44211;
      };
      "petcityhouston.com" = {
        hostname = "35.236.219.140";
        user = "petcityhouston";
        port = 35768;
      };
      "petland-dalton.com" = {
        hostname = "35.236.219.140";
        user = "petlanddaltoncom";
        port = 30730;
      };
      "petland-memphis.com" = {
        hostname = "35.236.219.140";
        user = "petlandmemphis";
        port = 33109;
      };
      "petland-ohio.com" = {
        hostname = "35.236.219.140";
        user = "petlandkingsdale";
        port = 36466;
      };
      "petlandashland.com" = {
        hostname = "35.236.219.140";
        user = "petlandashlandcom";
        port = 16946;
      };
      "petlandbatavia.com" = {
        hostname = "35.236.219.140";
        user = "petlandbatavia";
        port = 51493;
      };
      "petlandbeavercreek.com" = {
        hostname = "35.236.219.140";
        user = "petlandbeavercreek";
        port = 55543;
      };
      "petlandbradenton.com" = {
        hostname = "35.236.219.140";
        user = "petlandbradenton";
        port = 13358;
      };
      "petlandcarmel.com" = {
        hostname = "35.236.219.140";
        user = "petlandcarmel";
        port = 17349;
      };
      "petlandcicero.com" = {
        hostname = "129.80.57.27";
        user = "petlandcicero";
        port = 62257;
      };
      "petlandcleveland.com" = {
        hostname = "35.236.219.140";
        user = "petlandcleveland";
        port = 43941;
      };
      "petlanddayton.com" = {
        hostname = "35.236.219.140";
        user = "petlanddayton";
        port = 36174;
      };
      "petlanddunwoody.com" = {
        hostname = "35.196.5.93";
        user = "petlanddunwoodyp";
        port = 50827;
      };
      "petlandeastbroad.com" = {
        hostname = "34.162.230.19";
        user = "petlandeastbroad";
        port = 33153;
      };
      "petlandeastgate.com" = {
        hostname = "35.236.219.140";
        user = "petlandeastgate";
        port = 26819;
      };
      "petlandfairfield.com" = {
        hostname = "35.236.219.140";
        user = "petlandfairfield";
        port = 52800;
      };
      "petlandflorida.com" = {
        hostname = "35.236.219.140";
        user = "petlandflorida";
        port = 32799;
      };
      "petlandfortmyers.com" = {
        hostname = "35.236.219.140";
        user = "petlandfortmyers";
        port = 59470;
      };
      "petlandfrisco.com" = {
        hostname = "35.236.219.140";
        user = "petlandfriscocom";
        port = 24335;
      };
      "petlandgahanna.com" = {
        hostname = "35.236.219.140";
        user = "petlandgahanna";
        port = 65377;
      };
      "petlandgrovecity.com" = {
        hostname = "35.236.219.140";
        user = "petlandgrovecity";
        port = 56528;
      };
      "petlandheath.com" = {
        hostname = "35.236.219.140";
        user = "petlandheath";
        port = 61524;
      };
      "petlandhenderson.org" = {
        hostname = "35.236.219.140";
        user = "petlandhenderson";
        port = 50108;
      };
      "petlandiowacity.com" = {
        hostname = "35.236.219.140";
        user = "petlandiowacity";
        port = 53710;
      };
      "petlandjanesville.com" = {
        hostname = "35.236.219.140";
        user = "petlandjanesville";
        port = 14197;
      };
      "petlandkansascity.com" = {
        hostname = "35.236.219.140";
        user = "petlandoverlandpark";
        port = 58262;
      };
      "petlandknoxville.com" = {
        hostname = "35.236.219.140";
        user = "petlandknoxville";
        port = 36307;
      };
      "petlandlasvegas.com" = {
        hostname = "34.174.186.154";
        user = "petlandlasvegas";
        port = 28445;
      };
      "petlandleessummit.com" = {
        hostname = "35.236.219.140";
        user = "petlandindependence";
        port = 20185;
      };
      "petlandlewiscenter.com" = {
        hostname = "35.224.70.159";
        user = "petlandlewiscenter";
        port = 40303;
      };
      "petlandlexington.com" = {
        hostname = "34.162.230.19";
        user = "petlandlexington";
        port = 14819;
      };
      "petlandmallofgeorgia.com" = {
        hostname = "35.236.219.140";
        user = "petlandmallofgeorgia";
        port = 30332;
      };
      "petlandmiami.com" = {
        hostname = "35.236.219.140";
        user = "petlandkendall";
        port = 54579;
      };
      "petlandmontgomery.com" = {
        hostname = "35.236.219.140";
        user = "petlandmontgomery";
        port = 35950;
      };
      "petlandmurf.com" = {
        hostname = "35.236.219.140";
        user = "petlandmurfreesboro";
        port = 23239;
      };
      "petlandnht.com" = {
        hostname = "35.236.219.140";
        user = "petlandnorwin";
        port = 63514;
      };
      "petlandnovi.com" = {
        hostname = "35.236.219.140";
        user = "petlandnovi";
        port = 48237;
      };
      "petlandofwebster.com" = {
        hostname = "35.236.219.140";
        user = "petlandwebster";
        port = 51894;
      };
      "petlandoklahoma.com" = {
        hostname = "35.236.219.140";
        user = "petlandoklahoma";
        port = 15642;
      };
      "petlandpensacola.com" = {
        hostname = "35.236.219.140";
        user = "petlandpensacola";
        port = 37730;
      };
      "petlandracine.com" = {
        hostname = "35.236.219.140";
        user = "petlandracine";
        port = 28187;
      };
      "petlandrobinson.com" = {
        hostname = "35.236.219.140";
        user = "petlandrobinsonlehighvalleyw";
        port = 50012;
      };
      "petlandsanantonio.com" = {
        hostname = "35.196.247.55";
        user = "petlandsanantonio";
        port = 27150;
      };
      "petlandsarasota.com" = {
        hostname = "35.236.219.140";
        user = "petlandsarasota";
        port = 60853;
      };
      "petlandstl.com" = {
        hostname = "35.236.219.140";
        user = "petlandstl";
        port = 21204;
      };
      "petlandstrongsville.com" = {
        hostname = "35.236.219.140";
        user = "petlandstrongsville";
        port = 47027;
      };
      "petlandterrehaute.com" = {
        hostname = "35.236.219.140";
        user = "petlandterrehaute";
        port = 50966;
      };
      "petlandtexas.com" = {
        hostname = "35.236.219.140";
        user = "petlandtexas";
        port = 23538;
      };
      "petlandtopeka.com" = {
        hostname = "35.236.219.140";
        user = "petlandtopeka";
        port = 30594;
      };
      "petlandwestwichita.com" = {
        hostname = "35.236.219.140";
        user = "petlandwestwichita";
        port = 34274;
      };
      "petlandwichita.com" = {
        hostname = "35.236.219.140";
        user = "petlandwichita";
        port = 29480;
      };
      "petlandwoodlands.com" = {
        hostname = "35.236.219.140";
        user = "petlandwoodlands";
        port = 58295;
      };
      "puppiestampa.com" = {
        hostname = "35.236.219.140";
        user = "puppiestampa";
        port = 15716;
      };
      "puppycityva.com" = {
        hostname = "35.236.219.140";
        user = "puppycityva";
        port = 19429;
      };
      "pupworld.com" = {
        hostname = "35.224.70.159";
        user = "pupworld";
        port = 63105;
      };
      "saborvapors.com" = {
        hostname = "35.236.219.140";
        user = "svapors";
        port = 60625;
      };
      "scimac.com" = {
        hostname = "35.236.219.140";
        user = "scimac";
        port = 54747;
      };
      "tinypawsva.com" = {
        hostname = "35.236.219.140";
        user = "tinypaws";
        port = 30911;
      };
      "yourpuppyfl.com" = {
        hostname = "35.236.219.140";
        user = "yourpuppyfl";
        port = 39746;
      };
    };
    includes = [ "~/.ssh/config.d/*" ];
  };

  programs.bash = {
    enable = true;
    historySize = 10000;
    historyControl = [ "ignoredups" "erasedups" ];
    sessionVariables = {
      SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        # Remote development.
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-containers
        ms-vscode.remote-explorer

        # Nix.
        jnoortheen.nix-ide

        # Git.
        eamodio.gitlens

        # Editor.
        esbenp.prettier-vscode
        editorconfig.editorconfig
        usernamehw.errorlens
        streetsidesoftware.code-spell-checker

        # AI.
        anthropic.claude-code
        continue.continue

        # Docker.
        ms-azuretools.vscode-docker
      ];
      userSettings = {
        "editor.formatOnSave" = true;
        "editor.minimap.enabled" = false;
        "editor.tabSize" = 2;
        "files.trimTrailingWhitespace" = true;
        "files.insertFinalNewline" = true;
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.nil}/bin/nil";
        "remote.SSH.configFile" = "~/.ssh/config";
      };
    };
  };

  home.file.".continue/config.json".text = builtins.toJSON {
    models = [
      {
        title = "qwen3:14b (workstation)";
        provider = "ollama";
        model = "qwen3:14b";
        apiBase = "http://100.95.201.10:11434";
      }
      {
        title = "gemma3:12b (nas)";
        provider = "ollama";
        model = "gemma3:12b";
        apiBase = "http://100.87.216.16:11434";
      }
    ];
    tabAutocompleteModel = {
      title = "qwen3:14b";
      provider = "ollama";
      model = "qwen3:14b";
      apiBase = "http://100.95.201.10:11434";
    };
    tabAutocompleteOptions = {
      useCopyBuffer = false;
      maxPromptTokens = 1024;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "google-chrome.desktop";
      "x-scheme-handler/http" = "google-chrome.desktop";
      "x-scheme-handler/https" = "google-chrome.desktop";
      "x-scheme-handler/about" = "google-chrome.desktop";
      "x-scheme-handler/unknown" = "google-chrome.desktop";
    };
  };
}
