'use strict';

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as iconv from 'iconv-lite';

let config = {}
let globalStatus = {}

export function activate(context: vscode.ExtensionContext) {

    if(!initCheck()){
        return;
    }

    let disposable1 = vscode.commands.registerCommand('extension.runSelection', () => {
        // vscode.window.showInformationMessage('Hello World!');
        let deleteSelect=false;
        let enbaleQueue=true;
        runSelection(deleteSelect,enbaleQueue);
    });

    let disposable1_1 = vscode.commands.registerCommand('extension.runSelectionAndDelete', () => {
        // vscode.window.showInformationMessage('Hello World!');
        let deleteSelect=true;
        let enbaleQueue=false;
        runSelection(deleteSelect,enbaleQueue);
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
        let enbaleQueue=true;
        writeCurrentScript(text,filename,datestr,enbaleQueue)
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
        let enbaleQueue=false;
        writeCurrentScript("clear('"+filename+"')\r\napp.mainloop.run('"+filename+"')",filename,datestr,enbaleQueue)
        appendLog("app.mainloop.run('"+filename+"') % [full file]",filename,datestr)
    });

    let disposable4 = vscode.commands.registerCommand('extension.resetStatus', () => {
        let statusFile=config['statusFile']
        writeGBK(statusFile,'{"running":0,"qos":0,"todo":0}')
        vscode.window.showInformationMessage('重置成功');
    });

    context.subscriptions.push(disposable1);
    context.subscriptions.push(disposable1_1);
    context.subscriptions.push(disposable2);
    context.subscriptions.push(disposable3);
    context.subscriptions.push(disposable4);
}

// this method is called when your extension is deactivated
export function deactivate() {
}

function runSelection(deleteSelect: boolean,enbaleQueue: boolean){
    let editor = vscode.window.activeTextEditor;
    if (!editor) {
        return; // No open text editor
    }
    let fullText=editor.document.getText()
    let lines=fullText.split(/\r?\n/);
    let selection = editor.selection;
    let text ='';
    let deletecb=()=>{};
    if (selection.isEmpty) {
        let line = selection.active.line;
        let pattern=/^.*\.\.\.\s*(%.*)?$/;
        let startLine=line-1;
        for(;startLine>=0;startLine--){
            if(!pattern.test(lines[startLine]))break;
        }
        startLine++;
        let endLine=line;
        for(;endLine<lines.length;endLine++){
            if(!pattern.test(lines[endLine]))break;
        }
        endLine++;

        text = lines.slice(startLine,endLine).join('\r\n')
        deletecb=()=>{
            editor.edit(edit => {
                edit.replace(new vscode.Range(
                    new vscode.Position(startLine,0),
                    new vscode.Position(endLine,0)
                ), '');
            })
        }
    } else {
        text = editor.document.getText(selection);
        deletecb=()=>{
            editor.edit(edit => {
                edit.replace(selection, '');
            })
        }
    }

    let filename=editor.document.fileName

    console.log(text)
    console.log(filename)

    let datestr = new Date().toLocaleString()
    writeCurrentScript(text,filename,datestr,enbaleQueue)
    appendLog(text,filename,datestr)
    if(deleteSelect)deletecb();
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
    config['scriptQueue']=config['scriptLogPath']+'\\scriptQueue.m'
    if(!config['scriptLogPath'] || !config['currentScriptFile'] || !config['statusFile']){
        vscode.window.showErrorMessage('文件/路径未设置');
        return false;
    }
    let existed = fs.existsSync(config['scriptLogPath'])
    if(!existed){
        vscode.window.showErrorMessage('路径不存在');
        return false;
    }
    let existed2=fs.existsSync(config['scriptQueue'])
    if(!existed2){
        writeGBK(config['scriptQueue'],'');
    }
    return true;
}

function appendLog(str: string,filename: string,datestr: string){
    // let datestr = new Date().toLocaleString()
    // "2018-1-4 20:43:48"
    if(globalStatus['append'])str='% [queue.push]\r\n'+str;
    let text=[
        '%% DATE: '+datestr,
        '%% FILE: '+filename,
        str
    ].join('\r\n')
    let oldstr=''
    let logname=config['scriptLogPath']+'\\'+datestr.split(' ')[0].replace(/-\d\b/g,v=>'-0'+v[1])+'.mlog'
    try {
        oldstr=readGBK(logname)+'\r\n'
    } catch (error) {
        oldstr=''
    }
    writeGBK(logname,oldstr+text)
    console.log(text)
}

const spliter = '%% %%%%%%%%%spliter%%%%%%%%%a4eugb2sbb6cas4rg8s5vt9o6ng%%%%%';

function writeCurrentScript(str: string,filename: string,datestr: string,enbaleQueue: boolean){
    let statusstr=''
    try {
        statusstr=readGBK(config['statusFile'])
    } catch (error) {
        statusstr='{"running":0,"qos":0,"todo":0}'
    }
    let status=JSON.parse(statusstr)
    if(!status["qos"]){
        vscode.window.showErrorMessage('matlab环境未启动')
        throw Error('matlab环境未启动')
    }
    function writeToFile(targetfile: string,messege: string,append: boolean){
        status["import"]=status["import"]||''
        status['date']=datestr
        status['file']=filename
        status['todo']+=1
        let dateprefix=append?spliter+'\r\n':'';
        let text=[
            dateprefix+'%% DATE: '+datestr,
            '%% FILE: '+filename,
            status["import"]+str
        ].join('\r\n')
        let lines=str.split(/\r?\n/);
        lines.forEach(v=>{
            if(/^\s*import\s.*$/.test(v))status["import"]+=v+'\r\n';
        })
        if(append){
            text=readGBK(targetfile)+'\r\n'+text;
        }
        writeGBK(config['statusFile'],JSON.stringify(status))
        writeGBK(targetfile,text)
        vscode.window.showInformationMessage(messege);
        console.log(text)
    }
    globalStatus['append']=false;
    if((status["running"] || status["todo"])&& !enbaleQueue){
        vscode.window.showErrorMessage('当前有未运行完成的脚本')
        throw Error('当前有未运行完成的脚本')
    } else if(status["running"] || status["todo"]){
        globalStatus['append']=true;
        writeToFile(config['scriptQueue'],'加入队列...',true)
    } else {  // if(!(status["running"] || status["todo"])){
        writeToFile(config['currentScriptFile'],'脚本执行...',false)
    }
}