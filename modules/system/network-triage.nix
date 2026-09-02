{
  lib,
  pkgs,
  username,
  ...
}:

let
  llamaPackage = pkgs.llama-cpp.override { cudaSupport = true; };

  model = pkgs.fetchurl {
    url = "https://huggingface.co/empero-ai/Qwen3.8-4B-Distill-GGUF/resolve/main/Qwen3.8-4B-Q4_K_M.gguf";
    hash = "sha256-3slujPLhG2E7tGUT3sSFN3+cpaNR5xcS7g4kTyh8Z5A=";
  };

  triageCommand = lib.escapeShellArgs [
    "${pkgs.python3}/bin/python3"
    (toString ./network-triage.py)
    "--eve"
    "/var/log/suricata/eve.json"
    "--state-dir"
    "/var/lib/network-triage"
    "--summary"
    "/var/lib/network-triage/noteworthy.txt"
    "--socket"
    "/run/network-triage-llm/llama.sock"
    "--model"
    "qwen-network-triage"
  ];
in
{
  users = {
    groups.network-triage = { };
    users = {
      network-triage = {
        isSystemUser = true;
        group = "network-triage";
        extraGroups = [
          "render"
          "video"
        ];
      };
      ${username}.extraGroups = [ "network-triage" ];
    };
  };

  services = {
    suricata = {
      enable = true;

      enabledSources = [
        "abuse.ch/sslbl-blacklist"
        "abuse.ch/sslbl-c2"
        "abuse.ch/sslbl-ja3"
        "et/open"
      ];

      settings = {
        vars.address-groups.HOME_NET = "192.168.1.0/24";
        app-layer.protocols.modbus.enabled = "yes";

        pcap = [
          { interface = "wlp9s0"; }
        ];

        outputs = [
          {
            eve-log = {
              enabled = true;
              filetype = "regular";
              filename = "eve.json";
              community-id = true;
              types = [
                { alert = { }; }
                { dns = { }; }
                { tls = { }; }
                { flow = { }; }
              ];
            };
          }
        ];
      };
    };    
  };

  systemd.services = {
    network-triage-llm = {
      description = "Local LLM for Suricata event triage";
      wantedBy = [ "multi-user.target" ];
      after = [ "nvidia-persistenced.service" ];

      environment = {
        CUDA_VISIBLE_DEVICES = "0";
      };

      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          "${llamaPackage}/bin/llama-server"
          "--model"
          (toString model)
          "--alias"
          "qwen-network-triage"
          "--host"
          "/run/network-triage-llm/llama.sock"
          "--ctx-size"
          "32768"
          "--n-gpu-layers"
          "all"
          "--cache-type-k"
          "q8_0"
          "--cache-type-v"
          "q8_0"
          "--flash-attn"
          "on"
          "--parallel"
          "1"
          "--sleep-idle-seconds"
          "90"
          "--no-ui"
          "--no-slots"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        User = "network-triage";
        Group = "network-triage";
        RuntimeDirectory = "network-triage-llm";
        RuntimeDirectoryMode = "0750";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" ];
      };
    };

    network-triage = {
      description = "Triage recent Suricata events with a local LLM";
      wants = [
        "network-triage-llm.service"
        "suricata.service"
      ];
      after = [
        "network-triage-llm.service"
        "suricata.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = triageCommand;
        TimeoutStartSec = "5min";
        User = "network-triage";
        Group = "network-triage";
        StateDirectory = "network-triage";
        StateDirectoryMode = "0750";
        UMask = "0027";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" ];
        ReadOnlyPaths = [ "/var/log/suricata/eve.json" ];
        ReadWritePaths = [ "/var/lib/network-triage" ];
      };
    };
  };

  systemd.timers.network-triage = {
    description = "Periodically triage Suricata events";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "5min";
      Persistent = true;
      RandomizedDelaySec = "30s";
      Unit = "network-triage.service";
    };
  };
}
