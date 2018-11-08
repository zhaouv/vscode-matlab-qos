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

script queue

`F5` `F9` `Ctrl+Enter`

When you select nothing, `F9` will run those line instead of do nothing which is the default behavier in Matlab editor.

`F7` run selection or selected line and then delete those.

highlight when using V and [matlab.tmLanguage](http://172.16.20.52/tmp/matlab.tmLanguage)
```json
"editor.tokenColorCustomizations":{
    "textMateRules": [
        {
            "scope":"comment.line.double-percentage.matlab",
            "settings": {
                "fontStyle": "bold",
                "foreground": "#40b903"
            }
        },
        {
            "scope":"meta.comment.error.matlab",
            "settings": {
                "foreground": "#b90303"
            }
        },
        {
            "scope":"meta.comment.info.matlab",
            "settings": {
                "foreground": "#039eb9"
            }
        }
    ]
}
```

scripts log & error log & workspace log

## Requirements

win7^ & matlab2016b^

## Extension Settings

This extension contributes the following settings:

* `qos.scriptLogPath`: Path to put log file
* `qos.currentScriptFile`: matlab will run this file when vscode send messege
* `qos.statusFile`: vscode and matlab will check and write this file to communicate


