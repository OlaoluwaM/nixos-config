{
  fonts.fontconfig = {
    enable = true;

    configFile.berkeley-mono-spacing = {
      enable = true;
      priority = 50;
      label = "berkeley-mono-spacing";
      text = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <match target="scan">
            <test name="family">
              <string>Berkeley Mono</string>
            </test>
            <edit name="spacing" mode="assign">
              <int>100</int>
            </edit>
          </match>

          <match target="scan">
            <test name="family">
              <string>Berkeley Mono Variable</string>
            </test>
            <edit name="spacing" mode="assign">
              <int>100</int>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
