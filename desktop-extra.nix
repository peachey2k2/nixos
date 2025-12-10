pkgs: with pkgs; [
  {
    name = "java-jar-wrapper";
    desktopName = "Java JAR Wrapper";
    exec = "${jdk17_headless} %u";
    terminal = false;
    categories = [ "Application" ];
    mimeTypes = [ "application/java-archive" ];
  }
]
