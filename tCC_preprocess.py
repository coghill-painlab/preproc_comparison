#import packages from nipype

from nipype.algorithms.confounds import TCompCor
import sys

in_file = sys.argv[1]

print(in_file)

tccinterface = TCompCor()
tccinterface.inputs.realigned_file = in_file
tccinterface.inputs.num_components = 6
tccinterface.inputs.save_metadata = True
tccinterface.inputs.components_file = 'tCompCor_components.txt'
tccinterface.run()
