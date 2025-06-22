{
  enable = true;
  defaultApplications = let
    fileManager = "thunar.desktop";
    text = "Helix.desktop";
    image = "libresprite.desktop";
    pdf = "org.pwmt.zathura-pdf-mupdf.desktop";
    word = "freeoffice-textmaker.desktop";
    video = "vlc.desktop";
    archive = "xarchiver.desktop";
  in {
    "inode/directory" = fileManager;
    "text/plain" = text;
    "text/markdown" = text;
    "application/pdf" = pdf;
    "application/msword" = word;
    "video/x-matroska" = video;
    "application/zip" = archive;
    "image/png" = image;
  };
}
