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
        % ���ڼ���Ƿ�����Ҫ���еĽű�
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
        % ���ڼ�鵥��
        id
        % ��������Ϊtrue
        isinstance
    end
    properties (SetAccess = private, GetAccess = private)
        % ��ʱ��
        loopModContinue=1
        cleanInRunScriptInTimer
        timerClearInfo='clear all'
    end
    properties (SetAccess = private, GetAccess = private)
        % ����
        spliter='%% %%%%%%%%%spliter%%%%%%%%%a4eugb2sbb6cas4rg8s5vt9o6ng%%%%%'
    end
    methods (Static)
        % �����ھ�̬���������нű�
        run(scriptname)
    end
    methods
        % ÿһ���������нű��ĺ���
        function runScriptInTimer(obj)
            obj.cleanInRunScriptInTimer=1;
            cleanupObj = onCleanup(@()cleanFcn(obj));
            obj.readStatus();
            if obj.status.todo
                obj.status.todo=obj.status.todo-1;
                obj.status.running=1;
                obj.writeStatus();
                clear(obj.config.('qos_currentScriptFile'));
                try
                    addpath('.');
                    app.mainloop.run(obj.config.('qos_currentScriptFile'));
                catch exception
                    errorReport=exception.getReport;
                    lines=string(errorReport).split(sprintf('\n'));
                    si=1;
                    for si=1:size(lines,1)
                        if ~isempty(regexp(lines(si),'app\.mainloop\.run', 'once'))
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
                % ����ֹͣ��������ֹͣ
                obj.runScriptInTimerEnd();
            end
            % ʵʱ׷�ٹ������仯
            obj.checkUpWorkspace();
            obj.cleanInRunScriptInTimer=0;
            function cleanFcn(obj)
                if obj.cleanInRunScriptInTimer
                    obj.timerClearInfo='ctrl+c';
                    stop(obj.looptimer);
                end
            end
        end
        function runScriptInTimerEnd(obj)
            obj.readStatus();
            obj.status.running=0;
            obj.checkUpWorkspace();
            if obj.status.todo
                % �������ı�
                try
                    scriptQueueText=fileread(obj.config.('scriptQueue'));
                catch
                    pause(0.1)
                    scriptQueueText=fileread(obj.config.('scriptQueue'));
                end
                scriptQueue=string(scriptQueueText).split(obj.spliter);
                % ���¶�����
                obj.status.todo=numel(scriptQueue);
                % ����д����ǰ�ļ�
                fid=fopen(obj.config.('qos_currentScriptFile'),'w');
                fwrite(fid,scriptQueue(1));
                fclose(fid);
                obj.appendLog(sprintf('\n%% [queue.shift %d]',numel(scriptQueue)));
                % ���¶����ı�
                if numel(scriptQueue)>1
                    scriptQueueText=join(scriptQueue(2:end),obj.spliter);
                else
                    scriptQueueText='';
                end
                fid=fopen(obj.config.('scriptQueue'),'w');
                fwrite(fid,scriptQueueText);
                fclose(fid);
            end
            obj.writeStatus();
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
                    obj.appendLog(sprintf('\n%% [Break by Ctrl + C]'));
                    % ��Ctrl+C���ֹͣ
                    obj.runScriptInTimerEnd();
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
    
    % ��ʼ��,����,����,������֧�ִ���
    methods
        % ����͹�������
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
                fid=fopen(obj.config.('scriptQueue'),'w');
                fwrite(fid,'');
                fclose(fid);
            end
        end
    end
    methods
        % ��ʼ��
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
            % ȡ����
            if isfield(obj.inputargs,'configFile')
                obj.configFile=obj.inputargs.configFile;
            else
                mpath = mfilename('fullpath');
                ii=findstr(mpath,'\'); %#ok<FSTR>
                mpath=mpath(1:ii(end));
                obj.configFile=[mpath 'settings.json'];
            end
            if ~exist(obj.configFile,'file')
                error('�븴��_settings.json��settings.json������');
            end
            % ȡ״̬
            obj.config=jsondecode(fileread(obj.configFile));
            if ~exist(obj.config.('qos_statusFile'),'file')
                statustext='{"running":0,"qos":0,"todo":0}';
            else
                statustext=fileread(obj.config.('qos_statusFile'));
            end
            obj.status=jsondecode(statustext);
            obj.config.('scriptQueue')=[obj.config.('qos_scriptLogPath') '\scriptQueue.m'];
            if ~exist(obj.config.('scriptQueue'),'file')
                fid=fopen(obj.config.('scriptQueue'),'w');
                fwrite(fid,'');
                fclose(fid);
            end
            % matlab���̵ĵ������
            if ~isempty(app.mainloop.instance)
               error('�Ѵ������е�ʵ��,loop=app.mainloop.GetInstance��ȡ');
            end
            % �����ļ��ĵ������
            try
                obj.isinstance= strcmp(obj.status.id,obj.id);
            catch
                obj.isinstance=true;
            end
            if ~obj.isinstance
                error('��һ��matlab���Ѿ�����ʵ��,��ʹ�ñ������')
            end
            % ���óɹ�
            obj.instance(obj);
        end
        % ���ļ���������״̬
        function readStatus(obj)
            try
                statustext=fileread(obj.config.('qos_statusFile'));
                obj.status=jsondecode(statustext);
            catch
                pause(0.1);
                statustext=fileread(obj.config.('qos_statusFile'));
                obj.status=jsondecode(statustext);
            end
        end
        % ������״̬���µ��ļ�
        function writeStatus(obj)
            fid=fopen(obj.config.('qos_statusFile'),'w');
            fwrite(fid,jsonencode(obj.status));
            fclose(fid);
        end
        % ׷�ӵ���־
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