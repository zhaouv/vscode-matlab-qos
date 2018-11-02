# vscode-matlab-qos README

Run Matlab Scripts in Vscode.

add `+app`'s parent root into matlab PATH

create `+app/LP.m`
```matlab
function LP(varargin)
    if ~nargin
        varargin={'configFile','<full path>\.vscode\settings.json'};
    end
    app.mainloop.GetInstance(varargin{:});
end
```

Run `+app.LP` in matlab console

## Features

`F5` `F9` `Ctrl+Enter`

When you select nothing, `F9` will run those line instead of do nothing which is the default behavier in Matlab editor.

## Requirements

win7^ & matlab2016b^

## Extension Settings

This extension contributes the following settings:

* `qos.scriptLogPath`: Path to put log file
* `qos.currentScriptFile`: matlab will run this file when vscode send messege
* `qos.statusFile`: vscode and matlab will check and write this file to communicate

## Known Issues

wrong highlight for `%%\S.*` when use
```json
"editor.tokenColorCustomizations":{
    "textMateRules": [
        {
            "scope":"comment.line.double-percentage.matlab",
            "settings": {
                "fontStyle": "bold",
                "foreground": "#40b903"
            }
        }
    ]
}
```

## Release Notes

### 0.0.1

Initial release

+ `F5` `F9` `Ctrl+Enter` 
+ script log
+ reset status file

