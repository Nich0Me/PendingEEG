# PendingEEG
Analysis code for *Pending decisions alter the neural geometry and the latent dynamics of brain activity* (Menghi, Viganò, Johnston, Hofschildt, Penny, Fusi & Doeller).

Participants learned to map four shapes onto a left/right response, conditional on one of two contextual cues (planets). For two shapes the response is the same in both contexts (**resolved** trials, configurations 1 and 4); for the other two it depends on the context (**pending** trials, configurations 2 and 3). In the Stimulus-First task the shape is shown for 3 s before the context, creating a waiting period in which the decision is either resolved or still pending. EEG analyses focus on this waiting period.

All code is MATLAB. Scripts are standalone: each one loads the preprocessed data, runs one analysis and plots the result.

## Requirements

- MATLAB with the Statistics and Machine Learning Toolbox
- [FieldTrip](https://www.fieldtriptoolbox.org/). Most scripts were written against `fieldtrip-20220514`; `GLM_ComputeFlickeringSpectrum_Irasa.m` and `MakeTopoplot.m` need a recent release (2026 or later) for `method = 'irasa'` and the compiled cluster-statistics helpers.
- [Psychtoolbox](http://psychtoolbox.org/) (task code only)
- `refa8import` (TMSi REFA8 reader; preprocessing only)

Each script sets the FieldTrip path in its first lines with `addpath(...)`. Edit that line to point to your installation. Keep only one FieldTrip version on the path (`restoredefaultpath` before `addpath`), otherwise functions from different versions get mixed.

## Data layout
Scripts expect to be run from the repository root, with these folders next to them:

| Folder | Contents |
|---|---|
| `Participants_BEH/` | Behavioural log files, `<id>_StimFirst_Day<d>*.mat` and `<id>_CueFirst_Day<d>*.mat` |
| `Participants_EEG/` | Raw REFA8 recordings, `sbj<id>_<day>a.hdr` (Context-First) and `sbj<id>_<day>b.hdr` (Stimulus-First) |
| `Preprocessed/` | Output of `Preprocess_Data.m`: `sbj_<id>_Day<d>-StimPreprocessed.mat` / `-CuePreprocessed.mat`, each holding `preprocessed`, `layout` and `neighbours` |

Intermediate folders (`RSA_ERPs/`, `RSA_Empirical/`, `RSA_Models/`, `Res_*`, `Figures/`) are created or filled by the scripts below.

EEG analyses use 28 participants: `subjects = [1:20, 22:28, 30]` (21 and 29 excluded for data quality).

### Time convention

Epochs are locked to **context onset (t = 0)**. In the Stimulus-First task the shape appears at about −3 s, so:

- pre-stimulus baseline: −4 to −3 s
- waiting period (stimulus on, context not yet shown): −3 to 0 s
- post-context: 0 s onwards

### `trialinfo` columns

| Column | Content |
|---|---|
| 2 | Trial number |
| 3 | Context cue (1 or 2) |
| 4 | Action (1 = `a`, 0 = `k`, 2 = no response) |
| 5 | RT (s, from context onset) |
| 6 | Feedback (1 = correct) |
| 7 | Missed (1 = no response) |
| 8 | Correct outcome / response (1 or 0) |
| 9 | Configuration (1–4; 1 and 4 = resolved, 2 and 3 = pending) |

## Pipeline

Run the scripts in this order. Most have a `cue_first` flag at the top: `0` = Stimulus-First task (the one analysed in the paper), `1` = Context-First task.

### 1. Task and behaviour

| Script | What it does |
|---|---|
| `TaskLauncher.m` | Builds the trial list for a session (200 trials on Day 1, 240 on Day 2, balanced over configuration × context) and launches the task |
| `StimFirstTask.m` | Psychtoolbox implementation of the Stimulus-First task |
| `BehavioralResults.m` | Accuracy and RT per day, block, context and resolved/pending configuration (Fig. 1D–E). Excludes missed trials and RTs < 150 ms |

### 2. Preprocessing
`Preprocess_Data.m` is interactive and run once per participant and day (set `participant_number`, `day` and `cue_first` at the top). It reads the raw REFA8 data, high-pass filters, re-references to the common average, epochs around context onset, attaches the behavioural `trialinfo`, and then walks through visual artefact rejection, bad-channel interpolation, ICA (fastICA) and component rejection, and final low-pass / line-noise filtering. Bad channels and rejected ICA components are set by hand in the script for each participant.

### 3. Evoked responses

| Script | What it does |
|---|---|
| `MakeTopoplot.m` | Grand-average topographies per time bin for resolved, pending and their difference, with a channel × time cluster-based permutation test (Supplementary Fig. 2) |

### 4. Decoding and representational similarity (Fig. 2)

| Script | What it does |
|---|---|
| `RunClassifier_ConcData.m` | Time-generalised SVM decoding (10-fold CV) of context, concatenating both days |
| `Plot_ClassifierAcc.m` | Plots temporal-generalisation matrices and the diagonal |
| `Plot_ClassifierPreDicho.m` | Plots cross-condition generalisation results (group mean ± SEM of the diagonal) |
| `Compute_RSA_ERP.m` / `Compute_RSA_ERP_ReOnset.m` | Condition-average ERPs for the 8 stimulus × context conditions (30 Hz low-pass, 250 Hz), locked to context onset or re-locked to the response (±1 s) |
| `Compute_RSA_Empiricals.m` | Correlation-distance RDMs at each time point |
| `Compute_RSA_ModelMat.m` | Model RDMs: decision state (resolved vs pending) and motor response |
| `Compute_RSA_Correlation.m` | Regresses each neural RDM on the model RDMs over time |

### 5. Dimensionality (Fig. 3)

| Script | What it does |
|---|---|
| `Dimensionality_maintenance.m` | Participation ratio (PR) of the channel covariance per trial in the waiting period, resolved vs pending |

### 6. Context readout dynamics (Fig. 4)

These scripts share one approach. A GLM fitted to post-context activity (100–400 ms) with outcome and context regressors gives one weight per channel for each regressor. Projecting single-trial EEG (20 ms moving average) onto these weights gives a time series per trial that indicates which context the activity favours.

| Script | What it does |
|---|---|
| `GLM_CheckDecoding.m` | Checks that the GLM axes decode context and response from held-out post-context trials |
| `GLM_ComputeFlickering_NullSpace.m` | Boundary-crossing ("flicker") rate on the outcome and context axes, and on a null-space control axis (first PC of the GLM residuals), resolved vs pending (Fig. 4A, C) |
| `GLM_ComputeFlickeringSpectrum_Irasa.m` | Power and amplitude spectra of the context readout, IRASA separation of aperiodic and oscillatory power, band tests (4–6, 7–9, 10–12 Hz, Holm-corrected) and cluster tests over frequency (Fig. 4B) |
| `Corr_Dimensionality_Flickering.m` | Trial-wise correlation between PR and crossing rate, per participant and condition (Fig. 4D) |

The analysis window for crossings and spectra is set by `toi2` near the top of each script: `[-3 -0.1]` for the waiting period, or a window before −3 s for the pre-stimulus baseline control.

## Statistics

Group-level tests are paired *t*-tests across participants or cluster-based permutation tests: FieldTrip's `ft_timelockstatistics` for channel × time data, and a sign-flip implementation (`cluster_perm_paired`, defined inside the scripts) for one-dimensional time or frequency data.

## Contact

Nicholas Menghi (menghi@cbs.mpg.de) and Simone Viganò (simone.vigano@cea.fr)
