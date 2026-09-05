{
  pkgs,
  lib,
  username,
  homeDirectory,
  ...
}:

let
  vault = "${homeDirectory}/Documents/Obsidian";
  configDir = "${homeDirectory}/.config/obsidian-vault";

  plugin =
    {
      id,
      repo,
      version,
      hashes,
      tag ? version,
    }:
    let
      files = builtins.attrNames hashes;
    in
    {
      inherit id;
      package = pkgs.runCommand "obsidian-plugin-${id}-${version}" { } ''
        mkdir -p "$out"
        ${lib.concatMapStringsSep "\n" (file: ''
          ln -s "${
            pkgs.fetchurl {
              url = "https://github.com/${repo}/releases/download/${tag}/${file}";
              hash = hashes.${file};
            }
          }" "$out/${file}"
        '') files}
      '';
    };

  plugins = [
    (plugin {
      id = "dataview";
      repo = "blacksmithgu/obsidian-dataview";
      version = "0.5.68";
      hashes = {
        "main.js" = "sha256-a7HPcBCvrYMOc1dfyg4r+9MnnFYuPZ0k8tL0UWHrfQA=";
        "manifest.json" = "sha256-kjXbRxEtqBuFWRx57LmuJXTl5yIHBW6XZHL5BhYoYYU=";
        "styles.css" = "sha256-MwbdkDLgD5ibpyM6N/0lW8TT9DQM7mYXYulS8/aqHek=";
      };
    })
    (plugin {
      id = "obsidian-git";
      repo = "Vinzent03/obsidian-git";
      version = "2.38.5";
      hashes = {
        "main.js" = "sha256-u0YYGzZxWz93ahwkZ/zbvi4jxO/nux2b8wJwDUK2AZ8=";
        "manifest.json" = "sha256-qqfMsQ9jfPNhoLZZL5M3k5b5uqlDAAr8pCrULrVSZRY=";
        "styles.css" = "sha256-9auT9NW03RvR5XeGTFx5CH9639RIrDRuBInlhHzmki0=";
      };
    })
    (plugin {
      id = "calendar-beta";
      repo = "liamcain/obsidian-calendar-plugin";
      version = "2.0.0";
      tag = "2.0.0-beta.2";
      hashes = {
        "main.js" = "sha256-ZNHGxiCAMkZyS8kixcLgoXxAb/wj9rvPv7FMZDlY+7c=";
        "manifest.json" = "sha256-MU/BeSmiJwsX6jklOO4tkzMHFIAOJEspdbbBn5uNxok=";
        "styles.css" = "sha256-SGtFAHbzQ5ueQIU2ZaP1HlCEyrpguILChbYPR2TCCFI=";
      };
    })
    (plugin {
      id = "periodic-notes";
      repo = "liamcain/obsidian-periodic-notes";
      version = "0.0.17";
      hashes = {
        "main.js" = "sha256-k0ypQ1m2pLnwIJPUpE+lllTFI3sxzwLXuYLFgWiFG7E=";
        "manifest.json" = "sha256-vaKTI/ddOz/L2kiTNYJbl/5LV0kU0EY16afmfyQUBJw=";
        "styles.css" = "sha256-/ywAte550Y0C56j0jLLmUSyRL3X4juBT2UZoyQqWs5o=";
      };
    })
    (plugin {
      id = "templater-obsidian";
      repo = "SilentVoid13/Templater";
      version = "2.22.1";
      hashes = {
        "main.js" = "sha256-2nnmntm8GDtBNFi/mR4yLY0ahv9Dwu4wQxHBh2PI9KQ=";
        "manifest.json" = "sha256-0vGmMfRBZK2FcAE8Fr234LWUrSgkIfPnBaCmfCk4kHw=";
        "styles.css" = "sha256-65QGO+YCZ585fj41/Lf2pLAn2oLhfCE7tEomfGtF2N4=";
      };
    })
    (plugin {
      id = "obsidian-tasks-plugin";
      repo = "obsidian-tasks-group/obsidian-tasks";
      version = "8.2.1";
      hashes = {
        "main.js" = "sha256-TmETQ6h1m2eMY926v+lsxKXSKK/SeLu/hjTOg0YysaI=";
        "manifest.json" = "sha256-ochJwauaw55FDel1yIfPniWH+h0B3vKh2BZxFaotsGo=";
        "styles.css" = "sha256-MrPTlLaXoFjy3K7w04R2s8Plha6mNUmoFrzCN88+OHI=";
      };
    })
  ];

  writeIfMissing = path: text: ''
        if [ ! -e "${path}" ]; then
          cat > "${path}" <<'EOF'
    ${text}EOF
          chown ${username}:users "${path}"
          chmod 0644 "${path}"
        fi
  '';
in
{
  system.activationScripts.obsidianVault = {
    text = ''
      install -d -o ${username} -g users "${vault}" \
        "${vault}/Inbox" \
        "${vault}/Daily" \
        "${vault}/Projects" \
        "${vault}/Reference" \
        "${vault}/Attachments" \
        "${vault}/Templates" \
        "${configDir}" \
        "${configDir}/plugins"

      if [ -e "${vault}/.obsidian" ] && [ ! -L "${vault}/.obsidian" ]; then
        backup="${vault}/.obsidian.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
        mv "${vault}/.obsidian" "$backup"
        chown -R ${username}:users "$backup"
      fi
      ln -sfn "${configDir}" "${vault}/.obsidian"
      chown -h ${username}:users "${vault}/.obsidian"

      ${lib.concatMapStringsSep "\n" (p: ''
        install -d -o ${username} -g users "${configDir}/plugins/${p.id}"
        for file in "${p.package}"/*; do
          ln -sfT "$file" "${configDir}/plugins/${p.id}/$(basename "$file")"
        done
      '') plugins}

      ${writeIfMissing "${vault}/Templates/Daily.md" ''
        # {{date:YYYY-MM-DD}}

        ## Plan

        - [ ] 

        ## Notes

        - 

        ## Done

        - 
      ''}
      ${writeIfMissing "${vault}/Templates/Weekly.md" ''
        # {{date:gggg-[W]ww}}

        ## Focus

        - 

        ## Active projects

        ```dataview
        LIST
        FROM "Projects"
        SORT file.mtime DESC
        LIMIT 10
        ```

        ## Tasks

        ```tasks
        not done
        sort by due
        limit 20
        ```
      ''}
      ${writeIfMissing "${vault}/.gitignore" ''
        .obsidian/workspace.json
        .obsidian/workspaces.json
        .trash/
      ''}
    '';
  };
}
