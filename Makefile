joblist: *.nix *.lock
	rm -rf joblist
	nix eval -f joblist.nix --write-to joblist
