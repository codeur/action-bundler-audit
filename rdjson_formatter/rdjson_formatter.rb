#!/usr/bin/env ruby
require 'json'

CRITICALITY_RANK = {
  unknown: 0,
  none: 0,
  low: 1,
  medium: 2,
  high: 3,
  critical: 3,
}

SEVERITY = ["UNKNOWN_SEVERITY", "INFO", "WARNING", "ERROR"]

gemfile_lock_path = ARGV[0] || "Gemfile.lock"
input_json = JSON.parse(STDIN.read)

max_criticality_rank = 0
results = input_json["results"]

diagnostics = results.map do |result|
  gem_name =  result.dig("gem", "name")

  message = <<~EOS
    Title: #{result.dig("advisory", "title")}
    Solution: upgrade to #{result.dig("advisory", "patched_versions").map{|v| "'#{v}'"}.join(', ')}
  EOS

  criticality = result.dig("advisory", "criticality").to_s.strip&.to_sym
  if CRITICALITY_RANK.key?(criticality)
    criticality_rank = CRITICALITY_RANK[criticality]
  else
    warn "Unknown criticality '#{criticality}' encountered, falling back to :unknown (#{gem_name}/#{result.dig("advisory", "id")})"
    criticality_rank = CRITICALITY_RANK[:unknown]
  end
  max_criticality_rank = [max_criticality_rank, criticality_rank].max

  line = `grep -n -E '^\s{4}#{gem_name}' #{gemfile_lock_path} | cut -d : -f 1`.to_i

  {
    message: message,
    location: {
      path: gemfile_lock_path,
      range: {
        start: {
          line: line,
          column: 0
        }
      }
    },
    severity: SEVERITY[criticality_rank],
    code: {
      value: result.dig("advisory", "id"),
      url: result.dig("advisory", "url")
    }
  }
end

result = {
  source: {
    name: "bundler-audit",
    url: "https://github.com/rubysec/bundler-audit"
  },
  severity: SEVERITY[max_criticality_rank],
  diagnostics: diagnostics
}

puts result.to_json
