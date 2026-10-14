clear all
close all

cue_first = 0;

for s = [1:20,22:28,30]

    if cue_first == 1
        load(['./RSA_ERPs/sbj',num2str(s),'-CueFirst_reonset.mat'])
    else
        load(['./RSA_ERPs/sbj',num2str(s),'-StimFirst_reonset.mat'])
    end

    for t = 1:length(time)
    
    dissmat(:,:,t) = squareform(pdist([Conf1Cue1(:,t),Conf2Cue1(:,t),Conf3Cue1(:,t),Conf4Cue1(:,t),Conf1Cue2(:,t),Conf2Cue2(:,t),Conf3Cue2(:,t),Conf4Cue2(:,t)]','correlation'));
    
    end
    
    if cue_first == 1
        save(['./RSA_Empirical/sbj', num2str(s),'-CueFirst_reonset'],'dissmat','time')
    else
        save(['./RSA_Empirical/sbj', num2str(s),'-StimFirst_reonset'],'dissmat','time')
    end

end