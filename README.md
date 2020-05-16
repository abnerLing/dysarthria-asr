## Baseline UAspeech kaldi recipe

This is just a basic script for building a GMM-HMM based ASR with kaldi.
The script is similar to https://github.com/ffxiong/uaspeech and uses the exact same LM method but a few differences with the acoustic model training.

###### For example:
  - Included double delta training before applying lda_mllt training.
  - Speed and tempo augmentation options. 
  - Data preparation using python not bash.
  - Allowed the testing of different context windows.
  - After tri4 SAT training we re-aligning  with fmllr (feature space maximum likelihood linear regression).
 
 ## Before training..
 - Data will need to be downloaded from http://www.isle.illinois.edu/sst/data/UASpeech/
 - Since data preparation is in python you will need some libraries which can be pip installed
   - Pandas, numpy
 - There are some emppty files from the UAspeech which needs to be deleted. I included a npy file with the names of those files and they will get deleted from the data prep stage. But if you want to keep those for some reason, make sure to modify the prepare_ua_data.py script.  
  
  ## Results
  - Given the stochastic nature of the tasks your results may vary.
  
  Best GMM-HMM WER in [1] --> 44.91% (with re-segmentation) <br/>
  Best WER w/o augmentation --> %WER 40.82 [ 10085 / 24707, 0 ins, 1 del, 10084 sub ]exp/train/tri4/decode_test/wer_9_0.0 <br/>
  Best WER with augmentation --> %WER 39.97 [ 9876 / 24707, 0 ins, 8 del, 9868 sub ]exp/train_sp/tri4/decode_test/wer_7_0.0
  
  
  ## Individual results for best model
  - The table starts from mild dysarthria and ends with severe dysarthria.
  
| Speaker  | WER (%) |
| -------- | ------- |
| F05  | 8.57  |
| M10  | 8.57  |
| M08  | 12.66  |
| M09  | 18.49  |
| M14  | 13.95  |
| F04  | 31.15  |
| M11  | 36.54  |
| M05  | 32.94  |
| M16  | 39.80  |
| F02  | 57.14  |
| M07  | 43.03  |
| M01  | 79.61  |
| M12  | 81.05  |
| F03  | 79.58  |
| M04  | 94.27  |
| Total  | 39.97  |


## References
[1] F. Xiong, J. Barker, and H. Christensen, "Phonetic Analysis of Dysarthric Speech Tempo and Applications to Robust Personalised Dysarthric Speech Recognition," in IEEE International Conference on Acoustics, Speech and Signal Processing (ICASSP), Brighton, UK, May 2019


##### Things to work on
- Make data augmentation more flexible
- Allow for speaker independent models
- Write bash-based script for data prep?
