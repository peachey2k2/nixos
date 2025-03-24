pkgs: with pkgs; {
  java_jar = {
    name = "Java JAR Wrapper";
    exec = "${jdk17_headless} %u";
    terminal = false;
    categories = [ "Application" ];
    mimeType = [ "application/java-archive" ];
  };
}
