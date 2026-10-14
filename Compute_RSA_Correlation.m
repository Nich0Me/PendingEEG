clear all
close all

Task = 1;

cue_first = 0;
load ./RSA_Models/ModelsMats.mat

counter = 1;
for s = [1:20,22:28, 30]
    if cue_first == 1
        load(['./RSA_Empirical/sbj',num2str(s),'-CueFirst_reonset'])
    else
        load(['./RSA_Empirical/sbj',num2str(s),'-StimFirst_reonset'])
    end

    if Task == 1
        idx = 1:4;
    else
        idx = 5:8;
    end

    for t = 1:length(time)

        %r(counter,t) = corr(squareform(dissmat(idx,idx,t))',squareform(ModelUncertainty)');
        %                 r1(counter,t) = corr(squareform(dissmat(idx,idx,t))',squareform(ModelResponseT1)');
        %                 r2(counter,t) = corr(squareform(dissmat(idx,idx,t))',squareform(ModelResponseT2)');
        % PARTIAL CORR
%                 temp = partialcorr([squareform(dissmat(idx,idx,t))',squareform(ModelResponseT1)'],squareform(ModelUncertainty)');
%                 resp(counter,t) = temp(2);
%                 temp = partialcorr([squareform(dissmat(idx,idx,t))',squareform(ModelUncertainty)'],squareform(ModelResponseT1)');
%                 uncert(counter,t) = temp(2);

        % GLM
        if Task == 1
            b = glmfit([squareform(ModelUncertainty)',squareform(ModelResponseT1)'],squareform(dissmat(idx,idx,t))','normal');
        else
            b = glmfit([squareform(ModelUncertainty)',squareform(ModelResponseT2)'],squareform(dissmat(idx,idx,t))','normal');
        end
        uncert(counter,t) = b(2);
        resp(counter,t) = b(3);

    end

    counter = counter+1;
end

plot(time, mean(uncert))
hold on
plot(time, mean(resp))
ylim([-0.4,0.8])
legend('Uncertainty', 'Response')