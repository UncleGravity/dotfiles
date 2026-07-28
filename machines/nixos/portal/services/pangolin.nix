{config, ...}: {
  sops.secrets = {
    "pangolin/server-secret".sopsFile = ../secrets/secrets.yaml;
    "pangolin/cf-dns-token".sopsFile = ../secrets/secrets.yaml;
  };

  sops.templates = {
    "pangolin.env".content = ''
      SERVER_SECRET=${config.sops.placeholder."pangolin/server-secret"}
    '';
    # lego (traefik's ACME client) resolves the zone and answers the DNS-01
    # challenge with this token: needs Zone:Read + DNS:Edit on the target domain
    "traefik.env".content = ''
      CF_DNS_API_TOKEN=${config.sops.placeholder."pangolin/cf-dns-token"}
    '';
  };

  services.pangolin = {
    enable = true;
    baseDomain = "angel.pizza";
    dashboardDomain = "pangolin.angel.pizza";
    dnsProvider = "cloudflare";
    letsEncryptEmail = "viera.tech@gmail.com";
    openFirewall = true; # 80, 443, 51820/udp
    environmentFile = config.sops.templates."pangolin.env".path;
    # One wildcard cert (*.example.com) via DNS-01 instead of per-resource HTTP-01 certs.
    settings.domains.domain1.prefer_wildcard_cert = true;
  };

  services.traefik = {
    environmentFiles = [config.sops.templates."traefik.env".path];
    # ERROR (default) hides all ACME/lego progress; INFO is cheap and makes
    # cert issuance debuggable.
    staticConfigOptions.log.level = "INFO";
    # Recursive resolvers may retain the wildcard CNAME after Cloudflare publishes
    # the exact challenge TXT record, causing lego's propagation check to fail.
    staticConfigOptions.certificatesResolvers.letsencrypt.acme.dnsChallenge = {
      resolvers = ["1.1.1.1:53" "1.0.0.1:53"];
      propagation.disableChecks = true;
    };
  };
  # The wildcard application CNAME also matches _acme-challenge. Keep DNS-01
  # records at the literal challenge name instead of following that CNAME.
  systemd.services.traefik.environment.LEGO_DISABLE_CNAME_SUPPORT = "true";
}
