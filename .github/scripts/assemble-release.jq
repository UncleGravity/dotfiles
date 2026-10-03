sort_by(.host) as $targets
| ($matrix.include | map(select(.deploy) | {host: .name, agent}) | sort_by(.host)) as $expected
| if ($targets | map({host, agent})) != $expected then
    error("Deployment fragments do not match the discovered machines")
  elif ($targets | map(.agent) | unique | length) != ($targets | length) then
    error("Deployment agents must be unique")
  else
    {commit: $commit, runId: $runId, runAttempt: $runAttempt, targets: $targets}
  end
