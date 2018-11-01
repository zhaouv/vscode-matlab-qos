'use strict';

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as iconv from 'iconv-lite';

let config = {}

export function activate(context: vscode.ExtensionContext) {

    if(!initCheck()){
        return;
    }

    let disposable1 = vscode.commands.registerCommand('extension.runSelection', () => {
        // vscode.window.showInformationMessage('Hello World!');

        let editor = vscode.window.activeTextEditor;
        if (!editor) {
            return; // No open text editor
        }
        let fullText=editor.document.getText()
        let lines=fullText.split(/\r?\n/);
        let selection = editor.selection;
        let text =''
        if (selection.isEmpty) {
            let line = selection.active.line;
            text = lines[line]
        } else {
            text = editor.document.getText(selection);
        }

        let filename=editor.document.fileName

        console.log(text)
        console.log(filename)

        let datestr = new Date().toLocaleString()
        writeCurrentScript(text,filename,datestr)
        appendLog(text,filename,datestr)
    });

    let disposable2 = vscode.commands.registerCommand('extension.runCurrentSection', () => {
        // vscode.window.showInformationMessage('Hello World!');
        
        let editor = vscode.window.activeTextEditor;
        if (!editor) {
            return; // No open text editor
        }
        let pattern=/^\s*%%(?:\s+.*)?$/
        // console.log(pattern.test('%%a')) //false
        // console.log(pattern.test('%%')) //false
        // console.log(pattern.test('%% sad')) //true

        let fullText=editor.document.getText()
        let lines=fullText.split(/\r?\n/);
        let line = editor.selection.active.line;

        let startLine=line;
        for(;startLine>0;startLine--){
            if(pattern.test(lines[startLine]))break;
        }
        let endLine=line+1;
        for(;endLine<=lines.length;endLine++){
            if(pattern.test(lines[endLine]))break;
        }

        let text = lines.slice(startLine,endLine).join('\r\n')

        let filename=editor.document.fileName
        
        console.log(text)
        console.log(filename)

        let datestr = new Date().toLocaleString()
        writeCurrentScript(text,filename,datestr)
        appendLog(text,filename,datestr)
    });

    let disposable3 = vscode.commands.registerCommand('extension.runFile', () => {
        // vscode.window.showInformationMessage('Hello World!');
        
        let editor = vscode.window.activeTextEditor;
        if (!editor) {
            return; // No open text editor
        }
        
        let fullText=editor.document.getText()

        let filename=editor.document.fileName
        let text = fullText
        
        console.log(text)
        console.log(filename)

        let datestr = new Date().toLocaleString()
        writeCurrentScript("run('"+filename+"')",filename,datestr)
        appendLog("run('"+filename+"') % [full file]",filename,datestr)
    });

    let disposable4 = vscode.commands.registerCommand('extension.resetStatus', () => {
        let statusFile=config['statusFile']
        writeGBK(statusFile,'{"running":0,"qos":0,"todo":0}')
        vscode.window.showInformationMessage('重置成功');
    });

    context.subscriptions.push(disposable1);
    context.subscriptions.push(disposable2);
    context.subscriptions.push(disposable3);
    context.subscriptions.push(disposable4);
}

// this method is called when your extension is deactivated
export function deactivate() {
}

function writeGBK(filename: string,str: string){
    let encoded = iconv.encode(str, 'gbk'); // 转换成gbk
    fs.writeFileSync(filename, encoded);
}
// let filename='E:/workspace/vscode/vscode-matlab-qos/temp.m';
// let text = readGBK(filename)

function readGBK(filename: string){
    let buffer = Buffer.from(fs.readFileSync(filename,{encoding:'binary'}),'binary');
    let text = iconv.decode(buffer,'GBK');//使用GBK解码
    return text;
}
// let filename2='E:/workspace/vscode/vscode-matlab-qos/temp2.m';
// writeGBK(filename2,'中gbk文')

function initCheck(){
    config['scriptLogPath']=vscode.workspace.getConfiguration('qos')['scriptLogPath']
    config['currentScriptFile']=vscode.workspace.getConfiguration('qos')['currentScriptFile']
    config['statusFile']=vscode.workspace.getConfiguration('qos')['statusFile']
    if(!config['scriptLogPath'] || !config['currentScriptFile'] || !config['statusFile']){
        vscode.window.showErrorMessage('文件/路径未设置');
        return false;
    }
    let existed = fs.existsSync(config['scriptLogPath'])
    if(!existed){
        vscode.window.showErrorMessage('路径不存在');
        return false;
    }
    return true;
}

function appendLog(str: string,filename: string,datestr: string){
    // let datestr = new Date().toLocaleString()
    // "2018-10-31 20:43:48"
    let text=[
        '%% DATE: '+datestr,
        '% FILE: '+filename,
        '% CONTENT:\r\n'+str
    ].join('\r\n')
    let oldstr=''
    let logname=config['scriptLogPath']+'\\'+datestr.slice(0,10)+'.mlog'
    try {
        oldstr=readGBK(logname)+'\r\n'
    } catch (error) {
        oldstr=''
    }
    writeGBK(logname,oldstr+text)
    console.log(text)
}

function writeCurrentScript(str: string,filename: string,datestr: string){
    let text=[
        '%% DATE: '+datestr,
        '% FILE: '+filename,
        str
    ].join('\r\n')
    let statusstr=''
    let statusFile=config['statusFile']
    try {
        statusstr=readGBK(statusFile)
    } catch (error) {
        statusstr='{"running":0,"qos":0,"todo":0}'
    }
    let status=JSON.parse(statusstr)
    if(!status["qos"]){
        vscode.window.showErrorMessage('matlab环境未启动')
        throw Error('matlab环境未启动')
    }
    if(status["running"]){
        vscode.window.showErrorMessage('当前有未运行完成的脚本')
        throw Error('当前有未运行完成的脚本')
    }
    status['date']=datestr
    status['file']=filename
    status['running']=1
    status['todo']=1
    writeGBK(statusFile,JSON.stringify(status))
    writeGBK(config['currentScriptFile'],text)
    vscode.window.showInformationMessage('脚本执行...');
    console.log(text)
}