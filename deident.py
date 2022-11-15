#!/bin/python3
'''
    Written By UoM Team
    Complete Sorter and De-Identifier in Python3
'''


def _create_dic_from_translation_table(table):
    '''
    Read the text file form translation table.
    First element of each row is Deidentified variable for particular PatientID
    '''
    global dic

    # open the table file.
    with open(table, 'r') as transt_file:

        # Looping through one line at a time
        for line in transt_file:

            # Split each line with comma seperator and convert to a list
            # eg : TEST_001, 93214 -> ['TEST_001', '93214']
            tup = line.strip('\n').strip(',').split(',')
            for i in range(len(tup)-1):
                # converting the list to a dict/hashmap
                dic[tup[i+1]] = tup[0]


def _mreplace(text, wordDic):
    '''
    replace words that match a key in a dict with the associated text value
    return the changed text
    '''

    rc = re.compile('|'.join(map(re.escape, wordDic)))

    def translate(match):
        return wordDic[match.group(0)]

    return rc.sub(translate, text)


def _anonsort(filename, foldername, remove_private_tags=True):
    '''
    annomize and sort
    filename : source files
    newloc : destnation of sorted files
    remove_private_tags : remove PN and PID/UI
    '''

    global dic, dupfiles, rep_dic

    def PN_callback(ds, data_element):
        if data_element.VR == 'PN':
            data_element.value = de_name

    # check if it is a dicom file
    try:
        ds = pydicom.read_file(filename)
    except:
        print("Not a dicom file.")
        return

    # check for patient id in the file
    try:
        de_name = dic[ds.PatientID]
    except:
        print("Dictionary does not has the key.")
        return

    # --
    try:
        ds.walk(PN_callback)
    except:
        pass
        # print(f"Check this file : {filename}.")

    # changing patient name and Deidentification check
    ds.PatientID = de_name
    ds.PatientIdentityRemoved = "YES"
    ds.DeidentificationMethod = 'gsharma@unimelb.edu.au'

    # Delete any other identies present in the file
    for name in ['OtherPatientIDs', 'OtherPatientIDsSequence']:
        if name in ds:
            delattr(ds, name)

    # Changing the institution name and address
    try:
        ds.InstitutionName = de_name
        ds.InstitutionAddress = de_name
    except:
        pass

    # changing the values to NA/0 if not present in the file
    try:
        if "SeriesDescription" not in ds:
            ds.SeriesDescription = 'NA'
    except:
        pass

    try:
        if "InstanceNumber" not in ds:
            ds.InstanceNumber = "NA"
            inst_number = "NA"
        else:
            inst_number = format(ds.InstanceNumber, '05d')
    except:
        inst_number = "NA_IN"

    # print(f"Checking : {filename}")
    # checking seriesname and series instanceUID
    try:
        seriesName = _mreplace(ds.SeriesDescription, rep_dic)
    except:
        seriesName = "NAseriesDescription"

    try:
        if "SeriesInstanceUID" not in ds:
            ds.SeriesInstanceUID = '1.2018.GS.4444'
    except:
        pass

    try:
        if ds.SeriesNumber not in ds:
            ds.SeriesNumber = NA
    except:
        pass


    # Generating the file and folder name
    studytime, sep, tail = (ds.StudyTime).partition('.')
    # foldername = foldername+'/'+de_name+'/'+str(ds.StudyDate)+'T'+studytime+'/'+str(ds.SeriesNumber)+'_'+str(seriesName)
    # fname = de_name+'_'+str(ds.Modality)+'_'+str(ds.StudyDate)+studytime+'_'+str(ds.SeriesNumber)+'_'+str(ds.SeriesInstanceUID)+'_'+str(ds.InstanceNumber)

    # using f-strings : faster and more readable
    foldername = f'{foldername}/{de_name}/{str(ds.StudyDate)}T{studytime}/{str(ds.SeriesNumber)}_{str(seriesName)}'
    fname = f'{de_name}_{str(ds.Modality)}_{str(ds.StudyDate)}{studytime}_{str(ds.SeriesNumber)}_{str(ds.SeriesInstanceUID)}_{inst_number}.dcm'

    # making folders and files
    if not os.path.exists(foldername):
        os.makedirs(foldername)

    if not os.path.isfile(foldername+'/'+fname):
        ds.save_as(foldername+'/'+fname)
        print(f'**** DE-IDENT SUCCESS ****\nInput :{filename}\nOutput :{fname}\n')
    else:
        print("Duplicate......")
        fname = str(fname+'~')
        ds.save_as(foldername+'/'+fname)
        dupfiles.append(filename)


if __name__ == '__main__':

    # global variables def and assignment

    global dupfiles, dic, rep_dic

    rep_dic = {
        ' ': '_',
        '^': '_',
        '/': '_',
        '__': '_',
        '  ': '_',
        '\\': '_',
        ']': '',
        '[': '',
        '(': '',
        ')': ''
    }

    dupfiles = []
    dic = {}

    # import required libraries
    try:
        import pydicom  # for accessing DICOM files
        import os
        import sys
        import re
        from time import perf_counter
        # from optparser import OptionParser
        # argparse recommended in python3
        import argparse

    except ImportError as e:
        print('Libraries missing')
        print(e)
        sys.exit()

    except Exception as e:
        print("Libraries are present. Other Error")
        print(e)
        sys.exit()

    # Parser Arguments
    parser = argparse.ArgumentParser(description='Input')
    parser.add_argument('-t', '--table', dest='tablename',
                        help='translation table',required=True)
    parser.add_argument('-s', '--source', dest='source', help='source data',required=True)
    parser.add_argument('-d', '--target', dest='target',
                        help='target destination',required=True)
    args = parser.parse_args()

    print("START")
    start = perf_counter()

    _create_dic_from_translation_table(args.tablename)

    # Going through each dir and file in the source dir
    if os.path.isdir(args.source):
        dname = os.path.basename(args.source)
        for root, dirs, files in os.walk(args.source):
            for each in files:
                _anonsort(os.path.join(root, each), args.target)

    print(f"Total Duplicate fiels = {len(dupfiles)}")

    end = perf_counter()
    print(f"Total time = {end - start}")

    print("END")
