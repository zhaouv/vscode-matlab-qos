classdef (Sealed = true)mainloop < handle
    % app.loop
    % app.mainloop.GetInstance
    % app.mainloop.instance
    % clear all
    % cc
    % delete(app.mainloop.GetInstance)
    % obj=app.mainloop.GetInstance
    % app.mainloop.GetInstance.status.id
    % lobj=obj
    properties (SetAccess = private)
        mod='timer' % timer loop
    end
    properties (SetAccess = private)
        % 用于检查是否有需要运行的脚本
        looptimer
        timeStep=0.01
    end
    properties (SetAccess = private)
        inputargs
        configFile
        config
        status
    end
    properties (SetAccess = private, GetAccess = private)
        % 用于检查单例
        id
        % 单例此项为true
        isinstance
    end
    properties (SetAccess = private, GetAccess = private)
        % 临时量
        loopModContinue=1
        cleanInRunScriptInTimer
        timerClearInfo='clear all'
    end
    methods
        % 用于在静态工作区运行脚本
        run(obj,scriptname)
        % 每一步尝试运行脚本的函数
        function runScriptInTimer(obj)
            obj.cleanInRunScriptInTimer=1;
            cleanupObj = onCleanup(@()cleanFcn(obj));
            try
                obj.readStatus();
            catch
                pause(0.1);
                obj.readStatus();
            end
            if obj.status.todo
                obj.status.todo=0;
                obj.writeStatus();
                clear(obj.config.('qos_currentScriptFile'));
                try
                    addpath('.');
                    obj.run(obj.config.('qos_currentScriptFile'));
                catch exception
                    errorReport=exception.getReport;
                    lines=string(errorReport).split(sprintf('\n'));
                    si=1;
                    for si=1:size(lines,1)
                        if ~isempty(regexp(lines(si),'app.mainloop/run'))
                            break
                        end
                    end
                    errorReport=char(join(lines(1:si-1),sprintf('\n')));
                    fprintf(2,'%s',errorReport);
                    %warning(errorReport)
                    obj.appendLog([sprintf('\n%% [ERROR]\n%%{\n') errorReport sprintf('\n%%}')]);
                    % exception.getReport
                    % rethrow(exception)
                end
                obj.status.running=0;
                obj.writeStatus();
            end
            obj.checkUpWorkspace();
            obj.cleanInRunScriptInTimer=0;
            function cleanFcn(obj)
                if obj.cleanInRunScriptInTimer
                    obj.timerClearInfo='ctrl+c';
                    obj.appendLog(sprintf('\n%% [Break by Ctrl + C]'));
                    obj.checkUpWorkspace();
                    stop(obj.looptimer);
                end
            end
        end
        function checkUpWorkspace(obj)
            persistent oldmap;
            if isempty(oldmap)
                oldmap=struct();
            end
            list={};
            newmap=getWorkspaceInfo();
            for name = fields(newmap)'
                name=name{1};
                if ~isfield(oldmap,name) || ~strcmp(newmap.(name),oldmap.(name))
                    list{end+1}=name;
                end
            end
            oldmap=newmap;
            if ~isempty(list)
                output={'' '% [workspace]' '%{'};
                for name = list
                    name=name{1};
                    output{end+1}=[name '= ' newmap.(name)];
                end
                output{end+1}='%}';
                obj.appendLog(join(output,sprintf('\n')));
            end
            function idmap= getWorkspaceInfo()
                idlist = evalin('base','whos');
                idlist=idlist(~ismember({idlist.name},{'ans'}));
                idmap=struct();
                for s = idlist'
                    str=[];
                    try
                        if ~ismember(s.class,{'char','string','struct','cell','double','logical','function_handle'})
                            str=[];
                        elseif strcmp(s.class,'function_handle')
                            str=evalin('base',['func2str(' s.name ')']);
                        else
                            str=evalin('base',['jsonencode(' s.name ')']);
                        end
                        if size(str,2) > 1000
                            str=[];
                        end
                    catch
                    end
                    if isempty(str)
                        str=jsonencode(struct('class',s.class,'size',s.size,'bytes',s.bytes));
                    end
                    idmap.(s.name)=str;
                end
            end
        end
        function initLoop(obj)
            while(obj.loopModContinue)
                obj.runScriptInTimer();
                pause(obj.timeStep)
            end
        end
        function initTimer(obj)
            t = timer('Period',obj.timeStep,'Name',['looptime' obj.id],'BusyMode','drop','ExecutionMode','fixedSpacing');
            t.TimerFcn = @(src,eventdata)TimerFcn(obj,t,src,eventdata);
            t.StopFcn = @(src,eventdata)StopFcn(obj,t,src,eventdata);
            obj.looptimer=t;
            start(t);
            function StopFcn(obj,t,~,~)
                obj.looptimer=[];
                delete(t);
                if strcmp(obj.timerClearInfo,'clear all')
                    obj.delete();
                elseif strcmp(obj.timerClearInfo,'ctrl+c')
                    obj.timerClearInfo='clear all';
                    obj.status.running=0;
                    obj.writeStatus();
                    obj.initTimer();
                end
            end
            function TimerFcn(obj,t,~,~)
                if isempty(app.mainloop.instance)
                    stop(t)
                    return
                end
                obj.runScriptInTimer()
            end
        end
    end
    
    % 初始化,配置,单例,构析等支持代码
    methods
        % 构造和构析函数
        function obj=mainloop(varargin)
            obj.inputargs=struct(varargin{:});
            obj.id=datestr(now,'yyyymmdd_HHMMSS');
            obj.loadConfig();
            obj.init();
        end
        function delete(obj)
            if obj.isinstance
                obj.instance([]);
                warning('off');
                delete(obj.looptimer);
                warning('on');
                fid=fopen(obj.config.('qos_statusFile'),'w');
                statustext='{"running":0,"qos":0,"todo":0}';
                fprintf(fid,statustext);
            end
        end
    end
    methods
        % 初始化
        function init(obj)
            obj.status.id=obj.id;
            obj.status.running=0;
            obj.status.qos=1;
            obj.writeStatus();
            if isfield(obj.inputargs,'mod')
                obj.mod=obj.inputargs.mod;
            end
            if strcmp(obj.mod,'timer')
                obj.initTimer();
                return;
            end
            if strcmp(obj.mod,'loop')
                obj.initLoop();
                return;
            end
        end
        function loadConfig(obj)
            % 取配置
            if isfield(obj.inputargs,'configFile')
                obj.configFile=obj.inputargs.configFile;
            else
                mpath = mfilename('fullpath');
                ii=findstr(mpath,'\'); %#ok<FSTR>
                mpath=mpath(1:ii(end));
                obj.configFile=[mpath 'settings.json'];
            end
            if ~exist(obj.configFile,'file')
                error('请复制_settings.json到settings.json并配置');
            end
            % 取状态
            obj.config=jsondecode(fileread(obj.configFile));
            if ~exist(obj.config.('qos_statusFile'),'file')
                statustext=['{"running":0,"qos":1,"id":"',obj.id,'","todo":0}'];
            else
                statustext=fileread(obj.config.('qos_statusFile'));
            end
            obj.status=jsondecode(statustext);
            % matlab进程的单例检查
            if ~isempty(app.mainloop.instance)
               error('已存在运行的实例,loop=app.mainloop.GetInstance获取');
            end
            % 配置文件的单例检查
            try
                obj.isinstance= strcmp(obj.status.id,obj.id);
            catch
                obj.isinstance=true;
            end
            if ~obj.isinstance
                error('另一个matlab中已经运行实例,请使用别的配置')
            end
            % 配置成功
            obj.instance(obj);
        end
        % 从文件更新运行状态
        function readStatus(obj)
            statustext=fileread(obj.config.('qos_statusFile'));
            obj.status=jsondecode(statustext);
        end
        % 把运行状态更新到文件
        function writeStatus(obj)
            fid=fopen(obj.config.('qos_statusFile'),'w');
            fwrite(fid,jsonencode(obj.status));
            fclose(fid);
        end
        % 追加到日志
        function appendLog(obj,charArray)
            filename =[obj.config.('qos_scriptLogPath') '\' datestr(now,'yyyy-mm-dd') '.mlog'];
            fid=fopen(filename,'a+');
            fprintf(fid,'%s',charArray);
            fclose(fid);
        end
    end
    methods (Static)
        function thisobj=GetInstance(varargin)
            % app.mainloop.GetInstance
            thisobj=app.mainloop.instance;
            if isempty(thisobj)
               thisobj=app.mainloop(varargin{:});
            end
        end
        function thisobj=instance(varargin)
            % app.mainloop.instance
            persistent this;
            if nargin
                this=varargin{1};
            end
            thisobj=this;
        end
    end
end