{# Read the original INI once. No service names, node names or source URLs here. #}
{{ set("input.text", replace(fetch(request.config), "\r", "")) }}
{% if not find(input.text, "(?m)^ruleset=") %}
{{ ERROR_cannot_read_rules_from_config }}
{% endif %}
{{ split(input.text, "\n", "input.lines") }}
{{ set("routing.direct_group", "DIRECT") }}
{% for line in input.lines %}
{% if startsWith(trim(line), "ruleset=") and exists("routing.default_group") %}
{{ ERROR_FINAL_or_MATCH_must_be_last_rule }}
{% endif %}
{% if startsWith(trim(line), "custom_proxy_group=") and endsWith(trim(line), "`select`[]DIRECT") %}
{{ set("routing.direct_group", replace(trim(line), "^custom_proxy_group=(.*?)`.*$", "$1")) }}
{% endif %}
{% if startsWith(trim(line), "ruleset=") and (endsWith(trim(line), ",[]FINAL") or endsWith(trim(line), ",[]MATCH")) %}
{{ set("routing.default_group", replace(trim(line), "^ruleset=([^,]+),.*$", "$1")) }}
{% endif %}
{% if startsWith(trim(line), "ruleset=") %}
{{ set("input.source", replace(trim(line), "^ruleset=[^,]+,", "")) }}
{% if not startsWith(input.source, "clash-classic:https://") and not startsWith(input.source, "clash-ipcidr:https://") and input.source != "[]FINAL" and input.source != "[]MATCH" and not startsWith(input.source, "[]GEOIP,") and not startsWith(input.source, "[]IP-CIDR,") and not startsWith(input.source, "[]IP-CIDR6,") %}
{{ ERROR_unsupported_ruleset_source }}
{% endif %}
{% if startsWith(input.source, "clash-") %}
{# Filename without query/fragment, extension and the optional _No_Resolve suffix. #}
{{ set("input.name", replace(replace(replace(replace(input.source, "[?#].*$", ""), "^.*/", ""), "(_No_Resolve)?[.](yaml|yml|rules)$", ""), "[^A-Za-z0-9_-]", "_")) }}
{% if input.name == "" %}
{{ ERROR_ruleset_URL_needs_filename }}
{% endif %}
{{ set("input.key", "registered.p_") }}
{{ append("input.key", input.name) }}
{% if exists(input.key) %}
{# Only collisions need a disambiguator. Bind it to source and group, not line number. #}
{{ append("input.name", "__") }}
{{ append("input.name", UrlEncode(input.source)) }}
{{ append("input.name", "__") }}
{{ append("input.name", UrlEncode(replace(trim(line), "^ruleset=([^,]+),.*$", "$1"))) }}
{{ set("input.key", "registered.p_") }}
{{ append("input.key", input.name) }}
{% if exists(input.key) %}
{{ ERROR_duplicate_ruleset_declaration }}
{% endif %}
{% endif %}
{{ set(input.key, "true") }}
{{ set("input.key", "names.") }}
{{ append("input.key", string(loop.index)) }}
{{ set(input.key, input.name) }}
{% endif %}
{% endif %}
{% endfor %}
{% if not exists("routing.default_group") %}
{{ ERROR_missing_FINAL_or_MATCH_rule }}
{% endif %}
# Generated from INI ruleset declarations; keep their original order.
mode: rule
log-level: info
dns:
  enable: true
  listen: 0.0.0.0:7874
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter: ['*.lan', '*.local', 'localhost']
  prefer-h3: false
  respect-rules: false
  default-nameserver: [223.5.5.5, 119.29.29.29]
  proxy-server-nameserver: [223.5.5.5, 119.29.29.29]
  nameserver:
    - 'https://8.8.8.8/dns-query#🖕 DNS'
  fallback: []
  nameserver-policy:
{% for line in input.lines %}
{% if startsWith(trim(line), "ruleset=") %}
{{ set("input.group", replace(trim(line), "^ruleset=([^,]+),.*$", "$1")) }}
{{ set("input.source", replace(trim(line), "^ruleset=[^,]+,", "")) }}
{% if startsWith(input.source, "clash-classic:") %}
    'rule-set:{{ at(names, loop.index) }}':
{% if input.group == routing.direct_group or input.group == "DIRECT" %}
      - 'https://8.8.8.8/dns-query#🖕 DNS'
{% else %}
      - 'https://1.1.1.1/dns-query#{{ replace(input.group, "'", "''") }}'
{% endif %}
{% endif %}
{% endif %}
{% endfor %}
rule-providers:
{% for line in input.lines %}
{% if startsWith(trim(line), "ruleset=") %}
{{ set("input.source", replace(trim(line), "^ruleset=[^,]+,", "")) }}
{% if startsWith(input.source, "clash-") %}
  '{{ at(names, loop.index) }}':
    type: http
{% if startsWith(input.source, "clash-classic:") %}
    behavior: classical
{% else %}
    behavior: ipcidr
{% endif %}
    format: yaml
    url: '{{ replace(replace(input.source, "^clash-(classic|ipcidr):", ""), "'", "''") }}'
    # Omit path: Mihomo keys the cache by URL, so inserting a rule cannot reuse another service's cache.
    interval: 86400
    proxy: '{{ replace(routing.default_group, "'", "''") }}'
{% endif %}
{% endif %}
{% endfor %}
rules:
{% for line in input.lines %}
{% if startsWith(trim(line), "ruleset=") %}
{{ set("input.group", replace(trim(line), "^ruleset=([^,]+),.*$", "$1")) }}
{{ set("input.source", replace(trim(line), "^ruleset=[^,]+,", "")) }}
{% if startsWith(input.source, "clash-") %}
  - 'RULE-SET,{{ at(names, loop.index) }},{{ replace(input.group, "'", "''") }}'
{% else if input.source == "[]FINAL" or input.source == "[]MATCH" %}
  - 'MATCH,{{ replace(input.group, "'", "''") }}'
{% else %}
  - '{{ replace(replace(input.source, "^[^]]*]", ""), ",no-resolve$", "") }},{{ replace(input.group, "'", "''") }}{% if endsWith(input.source, ",no-resolve") %},no-resolve{% endif %}'
{% endif %}
{% endif %}
{% endfor %}
