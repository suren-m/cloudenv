$pkg_mgr = "scoop"
$operation = "install"

# ---------- #
# Dev Tools
# ---------- #
$cli_tools = @(
"7zip",
"bat",
"busybox", # comes with sed, awk, vim, etc.
"gh",
"kustomize",
"lf",
"jq",
"ripgrep",
"tokei",
"watchexec",
"terraform",
"starship"
)

foreach($tool in $cli_tools) {
    $command = "$($pkg_mgr) $($operation) $($tool)"
    echo "executing...$command"
    Invoke-Expression $command	
}
