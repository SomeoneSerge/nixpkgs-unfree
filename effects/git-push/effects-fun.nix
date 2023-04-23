{ lib
, pkgs
}:

let
  inherit (lib)
    mkOption
    optionalString
    types
    ;

  cfg = config.git.push;

  # Copied from
  # https://github.com/hercules-ci/hercules-ci-effects/blob/15ff4f63e5f28070391a5b09a82f6d5c6cc5c9d0/effects/modules/git-auth.nix#L10-L16
  parseURL = gitRemote:
    let m = builtins.match "([a-z]*)://([^/]*)(/?.*)" gitRemote;
    in
    if m == null then throw "Could not parse the git remote as a url. Value: ${gitRemote}" else {
      scheme = lib.elemAt m 0;
      host = lib.elemAt m 1;
      path = lib.elemAt m 2;
    };

  source = parseURL cfg.source.url;
  destination = parseURL cfg.destination.url;
in
{
  options = {
    git.push.source.url = mkOption {
      description = ''
        GitHub repository to pull from
      '';
      type = types.str;
    };
    git.push.source.ref = mkOption {
      description = ''
        The source ref to pull
      '';
    };
    git.push.source.tokenSecret = mkOption {
      type = types.str;
      description = ''
        Name of the secret that contains the git token for the source repo.
      '';
      default = "token";
    };
    git.push.destination.url = mkOption {
      description = ''
        GitHub repository to push to
      '';
      type = types.str;
    };
    git.push.destination.ref = mkOption {
      description = ''
        The new git ref to push as
      '';
      type = types.str;
    };
    git.push.destination.tokenSecret = mkOption {
      type = types.str;
      description = ''
        Name of the secret that contains the git token for the destination repo.
      '';
      default = "token";
    };
    git.push.force = mkOption {
      description = ''
        Whether to --force push
      '';
      type = types.bool;
    };
    git.push.beforePush = mkOption {
      description = ''
        Extra commands to run prior to `git push`
      '';
      type = types.lines;
    };
  };
  config = {
    env.HCI_GIT_SOURCE_URL = cfg.source.url;
    env.HCI_GIT_SOURCE_REF = cfg.source.ref;
    env.HCI_GIT_DESTINATION_URL = cfg.destination.url;
    env.HCI_GIT_DESTINATION_REF = cfg.destination.ref;
    env.HCI_GIT_PUSH_FORCE = optionalString cfg.force "--force";

    # Copy-pasted from https://github.com/hercules-ci/hercules-ci-effects/blob/15ff4f63e5f28070391a5b09a82f6d5c6cc5c9d0/effects/modules/git.nix
    inputs = [
      pkgs.git
    ];
    env = {
      EMAIL = "hercules-ci[bot]@users.noreply.github.com";
      GIT_AUTHOR_NAME = "Hercules CI Effects";
      GIT_COMMITTER_NAME = "Hercules CI Effects";
      PAGER = "cat";
    };

    effectScript = ''
      # Based on https://github.com/hercules-ci/hercules-ci-effects/blob/15ff4f63e5f28070391a5b09a82f6d5c6cc5c9d0/effects/modules/git-auth.nix#L73-L74
      echo "${source.scheme}://${cfg.user}:$(readSecretString ${cfg.source.tokenSecret} .token)@${source.host}${source.path}" >>~/.git-credentials
      echo "${destination.scheme}://${cfg.user}:$(readSecretString ${cfg.destination.tokenSecret} .token)@${destination.host}${destination.path}" >>~/.git-credentials
      git config --global credential.helper store

      git clone "$HCI_GIT_SOURCE_URL" --branch "$HCI_GIT_SOURCE_REF" --single-branch "repo"
      cd "repo"
      git remote add "destination" "$HCI_GIT_DESTINATION_URL"

      ${cfg.beforePush}

      git push "$HCI_GIT_PUSH_FORCE" "destination" HEAD:"$HCI_GIT_DESTINATION_REF"
    '';
  };
}
