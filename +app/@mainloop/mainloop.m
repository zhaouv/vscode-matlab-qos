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
    methods
        % �����ھ�̬���������нű�
        run(obj,scriptname)
        % ÿһ���������нű��ĺ���
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
                    obj.run(obj.config.('qos_currentScriptFile'));
                catch exception
                    warning(exception.getReport)
                    fwrite(2,[exception.getReport, sprintf('\n') ])
                    % rethrow(exception)
                end
                obj.status.running=0;
                obj.writeStatus();
            end
            obj.cleanInRunScriptInTimer=0;
            function cleanFcn(obj)
                if obj.cleanInRunScriptInTimer
                    obj.timerClearInfo='ctrl+c';
                    stop(obj.looptimer);
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
                statustext=['{"running":0,"qos":1,"id":"',obj.id,'","todo":0}'];
            else
                statustext=fileread(obj.config.('qos_statusFile'));
            end
            obj.status=jsondecode(statustext);
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
            statustext=fileread(obj.config.('qos_statusFile'));
            obj.status=jsondecode(statustext);
        end
        % ������״̬���µ��ļ�
        function writeStatus(obj)
            fid=fopen(obj.config.('qos_statusFile'),'w');
            fwrite(fid,jsonencode(obj.status));
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