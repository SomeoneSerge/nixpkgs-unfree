# nixpkgs-unfree - nixpkgs with the unfree bits enabled


First, a word of warning: this is just a development repo that ought to be
replaced with something sustainable later. For an up-to-date information about
CUDA in nixpkgs seek in:

- [#cuda:nixos.org](https://matrix.to/#/#cuda:nixos.org)
- https://nixos.wiki/wiki/CUDA
- https://nixos.org/manual/nixpkgs/unstable/#cuda
- [discourse.nixos.org](https://discourse.nixos.org/t/announcing-the-nixos-cuda-maintainers-team-and-a-call-for-maintainers/)

With the above in mind, let's proceed.

## What is this

- This is a fork of @zimbatm's [nixpkgs-unfree](https://github.com/numtide/nixpkgs-unfree/)
- It's used to build and cache [nixpkgs](https://github.com/NixOS/nixpkgs)
  world with `cudaSupport = true`.
  See the dashboard at: [https://hercules-ci.com/github/SomeoneSerge/nixpkgs-unfree](https://hercules-ci.com/github/SomeoneSerge/nixpkgs-unfree)
  - This means you can use pre-built pytorch, tensorflow, jax and blender with Nix
  - This also means that [we](https://github.com/orgs/NixOS/teams/cuda-maintainers) notice and can act when things break in development branches.
    [We build](https://github.com/SomeoneSerge/nixpkgs-unfree/blob/7c716ccef51332e90777589c53265a09a3c0fbfa/.github/workflows/sync.yml#L14):

    - [`master`](https://github.com/NixOS/nixpkgs/tree/master/),
    - [`nixos-unstable`](https://github.com/NixOS/nixpkgs/tree/nixos-unstable),
    - [`nixpkgs-unstable`](https://github.com/NixOS/nixpkgs/tree/nixpkgs-unstable),
    - and the last release, at the time of writing - `nixos-21.11`

    All of them correspond to respective branches in this repo.
    These branches are automatically maintained, they derive from current
    [`develop`](https://github.com/SomeoneSerge/nixpkgs-unfree/tree/develop/), but
    [update the lock file `flake.lock`](https://github.com/SomeoneSerge/nixpkgs-unfree/blob/7c716ccef51332e90777589c53265a09a3c0fbfa/sync.sh#L26)
- The builds run [once a day](https://github.com/SomeoneSerge/nixpkgs-unfree/blob/7c716ccef51332e90777589c53265a09a3c0fbfa/.github/workflows/sync.yml#L5) so cache arrives with delays
- The cachix is limited in space and has garbage collection on. This means that
  you'd need to stay up-to-date to benefit from the cache (as we build newer
  packages, the old cache is eventually discarded)
- The builds currently run on volunteers' machines.
  We plan to soon make and maintain the exact list [on wiki](https://nixos.wiki/wiki/CUDA).
  Each machine uses its own key to push the build results to cachix and these keys can be revoked
  without breaking the whole chain.
  You consume just one public key listed at https://cuda-maintainers.cachix.org/.
  The cachix and cachix keys are currently managed by [@samuela](https://github.com/samuela/)

  We hope one day to arrive at a more sustainable and trust-worthy solution,
  but right now we're working on this as on a proof-of-concept.

## How to use

- To use the cache, get [cachix](https://cachix.org/), and execute:

  ```bash
  cachix use cuda-maintainers
  ```
- To use the cache on NixOS, check the following snippet for your `configuration.nix` module:

  ```nix
    nix.binaryCachePublicKeys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
    nix.binaryCaches = [
      "https://cuda-maintainers.cachix.org"
    ];
  ```

  Verify that the public key comes from https://cuda-maintainers.cachix.org
- You can also suggest the cache to users of your flake, with

  ```nix
    # ...

    nixConfig = {
      extra-substituters = [
        "https://cuda-maintainers.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };

    outputs = { ... }: {
      # ...
    };
  ```

  When interacting with your flake, the users would be asked whether they want to use that cache and trust that key.
- The most consistent way to use cuda-enabled packages from nixpkgs is to import them with the global `config.cudaSupport`:

  ```nix
  pkgs = import nixpkgs { config.allowUnfree = true; config.cudaSupport = true; }
  ```

  With that, `pkgs.python3Packages.jax`, `pkgs.python3Packages.pytorch`, etc evaluate into packages with cuda support.
- This flake attempts to play a drop-in replacement (rather, a proxy) for `nixpkgs`.
  The following usages are expected to work:

  - Executing `nix run github:SomeoneSerge/nixpkgs-unfree/nixpkgs-unstable#blender` to run blender built with cuda-support
  - Using in flake inputs: 

    ```nix
    inputs.nixpkgs.url = github:NixOS/nixpkgs/nixpkgs-unstable;
    inputs.nixpkgs-unfree.url = github:SomeoneSerge/nixpkgs-unfree;
    inputs.nixpkgs-unfree.inputs.nixpkgs.follows = "nixpkgs";
    ```
  - Using in flake inputs as a drop-in replacement for nixpkgs (unless someone does something special)

    ```nix
    inputs.nixpkgs.url = github:SomeoneSerge/nixpkgs-unfree/nixpkgs-unstable;
    inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
    ```
  - Importing as nixpkgs:

    ```nix
    inputs.nixpkgs = github:SomeoneSerge/nixpkgs-unfree/nixpkgs-unstable;
    outputs = { nixpkgs }:
    let
      system = "x86_64-linux";
      overlay = final: prev: { };
      pkgs = import nixpkgs { overlays = [ overlay ]; };
    in
    {
      # ...
    }
    ```

    Note that if you pass `config` in the arguments, you must again include `cudaSupport` and `allowUnfree`
- NOTE: Setting `<nixpkgs>` to point at this repo has proven a somewhat painful
  experience. Most problems concentrate around tools using 
  `import <nixpkgs/lib>`. There's a proxy in [./lib](./lib) right now which makes these import
  work, but almost certainly at the cost of downloading a yet another copy of
  nixpkgs...
- If you're not enabling the cache globally, you might need to set `trusted-users = ${yourName}` in `/etc/nix/nix.conf`.
