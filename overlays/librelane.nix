{inputs}: final: prev: {
  openroad = prev.openroad.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      (prev.fetchpatch {
        name = "fix-openroad-commit-2a8b2c7.patch";
        url = "https://github.com/The-OpenROAD-Project/OpenROAD/commit/2a8b2c7dcda87679a69df323b2ada5f3a21554ea.patch";
        hash = "sha256-vgmVpr+vHbOd8UUUUyJ8sTKi0Y7CWYatF006WX4+zFI=";
      })
    ];
    postPatch = (old.postPatch or "") + ''
      # Disable CutGTests because it misses core manager implementation
      # and fails under strict Nix linking. Filed as issue #9563.
      if [ -f src/cut/test/cpp/CMakeLists.txt ]; then
        echo "" > src/cut/test/cpp/CMakeLists.txt
      fi
    '';
  });

  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (python-final: python-prev: {
      libparse-python = python-prev.libparse-python.overrideAttrs (old: {
        meta = (old.meta or {}) // {
          platforms = prev.lib.platforms.all;
        };
      });
    })
  ];
}
