# vscode-matlab-qos README

Run Matlab Scripts in Vscode.

add `+app`'s parent root into matlab PATH

create `+app/LP.m`
```matlab
function LP()
    app.mainloop.GetInstance('configFile','<path to your .vscode/settings.json>');
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

* `qos.scriptLogPath`: enable/disable this extension
* `qos.currentScriptFile`: set to `blah` to do something
* `qos.statusFile`: set to `blah` to do something

## Known Issues

Calling out known issues can help limit users opening duplicate issues against your extension.

## Release Notes

Users appreciate release notes as you update your extension.

### 0.0.1

Initial release

+ `F5` `F9` `Ctrl+Enter` 
+ script log
+ reset status file

