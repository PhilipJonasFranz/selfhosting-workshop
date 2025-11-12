import os
import re
from pathlib import Path
from dotenv import dotenv_values

env_vars = dotenv_values(".workshop.env")

# Regex for matching $VAR or ${VAR}
pattern = re.compile(r'\$(\w+)|\$\{(\w+)\}')

def replace_env_vars_in_text(text):
    def replacer(match):
        var_name = match.group(1) or match.group(2)
        return env_vars.get(var_name, match.group(0))  # Only replace if exists
    return pattern.sub(replacer, text)

# Recursively process all files
for file_path in Path('.').rglob('*'):
    if file_path.is_file():
        try:
            content = file_path.read_text(encoding='utf-8')
            new_content = replace_env_vars_in_text(content)
            if new_content != content:
                file_path.write_text(new_content, encoding='utf-8')
        except (UnicodeDecodeError, PermissionError):
            # Skip binary or unreadable files
            continue
