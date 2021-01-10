#!/usr/bin/env python
"""
This python script is used to train a ML model for the "Rooms" iOS app.
Author: st0nedB
GitHub: https://github.com/st0nedB/
"""

import logging
import argparse
import numpy as np
import json
import os
import coremltools
import http.server, socketserver
# for preprocessing the data
from sklearn.preprocessing import OneHotEncoder
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelBinarizer
import matplotlib.pyplot as plt
# for learning
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Activation, Dropout
import tensorflow.keras.optimizers as optimizers
import tensorflow.keras.losses as losses
#from keras_tqdm import TQDMCallback
from sklearn.svm import SVC
from sklearn.model_selection import GridSearchCV

def get_options():
    description = ''
    parser = argparse.ArgumentParser(description=description)

    parser.add_argument('--num-beacon', help='The number of beacons used.', required=True, type=int)
    parser.add_argument('--num-epochs', help='The number of epochs to train for. Default = 300', type=int, default=300)
    parser.add_argument('--batch-size', help='The batch size to use for training. Default = 0.', type=int, default=0)
    parser.add_argument('--activation-function', help='The activation function to use. Default = "relu". Must be a valid keras activation function name.', type=str, default="relu")
    parser.add_argument('--http', help="Enables a simple http server to serve the file to the app.", nargs='?', const=True, default=False)
    parser.add_argument('--port', help="The port for the http server to run on.", nargs='?', type=int, const=8000, default=8000)

    return parser.parse_args()


def set_logging(level):
    logger = logging.getLogger()
    logger.setLevel(level)
    ch = logging.StreamHandler()
    logger.addHandler(ch)
    return logger

def loadData(nbeacon) -> (list, list, int):
    files = [file for file in os.listdir(".") if file.endswith(".json")]  # find all json files in the directory
    jsondata = []
    rooms = []
    nsamples = 0
    # read data and append to list, not very clean, but the amount of data is not very large
    for file in files:
        with open(file, "r") as jsonfile:
            try:
                fio = np.array(json.load(jsonfile))
                nsamples += fio.shape[0]
                rooms.append(str(file).split(".")[0])
                jsondata.append(fio)
            except:
                logging.warning("Skipping {:s} does not contain valid data.".format(str(file)))

    return jsondata, rooms, nsamples

def makeLabelBinarizer(rooms) -> LabelBinarizer:
    lb = LabelBinarizer()

    return lb.fit(rooms)

def parseData(jsondata, rooms, nsamples, lb) -> (np.array, np.array):
    # preallocate memory
    data = np.empty((nsamples,nbeacon))
    ohlabels = np.empty((nsamples,len(rooms)))

    ii = 0  # index to go through the data
    nn = dict.fromkeys(rooms)  # list with data amounts

    # iterate through data
    for dd,rr in zip(jsondata,rooms):
        N = np.shape(dd)[0]
        nn[rr] = N
        data[ii:ii+N] = dd
        ohlabels[ii:ii+N] = np.repeat(lb.transform([rr]), repeats=N, axis=0)
        ii += N

    data[data == -100] = 1  # this is due to a bug in AdditionalClasses.swift (fixed by commit 8555556ddc380be788b8e2b6f93a79a290acc7cc), leaving it here doesn't hurt and provides backwards compatibility.

    logging.info("Summary of loaded data:\n" + str(nn))

    return data, ohlabels

def makeModel(inputshape, nlabels, actfunc, dropout):
    """
    This creates the Keras model.
    A default model is created for all cases where nlabel > 2.
    A special case is binary classification (nlabels == 2). It should fix a bug, which would lead to predictions always being 50% likely.
    If nlabels == 1, we abort. Meaningful predictions can not be performed.
    """
    if nlabels < 2:
        # This means either no label or just one is given
        logger.error("More then one Room/Area must be provided!")

    if nlabels < 3:
        # This means we have to perform binary classification
        model = Sequential()
        model.add(Dense(8, input_shape=inputshape, activation=actfunc))
        model.add(Dense(4, activation=actfunc))
        model.add(Dropout(dropout))
        model.add(Dense(units=nlabels, activation="softmax"))
        model.compile(
            optimizer=optimizers.Adam(),
            loss="binary_crossentropy",
            metrics=["binary_crossentropy"]
        )

    else:
        model = Sequential()
        model.add(Dense(32, input_shape=inputshape, activation=actfunc))
        model.add(Dense(32, activation=actfunc))
        model.add(Dropout(dropout))
        model.add(Dense(16, activation=actfunc))
        model.add(Dropout(dropout))
        model.add(Dense(16, activation=actfunc))
        model.add(Dropout(dropout))
        model.add(Dense(units=nlabels, activation="softmax"))
        model.compile(
            optimizer=optimizers.Adam(),
            loss="categorical_crossentropy",
            metrics=['categorical_accuracy']
        )
        model.summary()

    return model

def trainModel(model, X_train, Y_train, X_test, Y_test, nepochs, nbatch):
    if nbatch == 0:
        nbatch = X_train.shape[0]

    model.fit(X_train, Y_train, epochs=nepochs, batch_size=nbatch, verbose=0, callbacks=[])
    score = model.evaluate(X_test, Y_test)

    return model, score

def makeSKlearnModel(data, cl2):
    X_train, X_test, Y_train, Y_test = data
    model = SVC(
        C=cl2, # L2 regularization parameter
        kernel="rbf",
        degree= 10, # only for polynomial kernel
        gamma="auto",
        decision_function_shape="ovr", # one-vs-rest (ovr) or one-vs-one (ovo)
        probability=True,
        tol=1e-3,
    )
    model.fit(X_train, Y_train)
    score = model.score(X_test, Y_test)

    return model, score

def convertCoreMLSklearn(sklearn_model):
    """
    Convert sklearn model to coreml model
    """
    modelName = "rooms_coreml"
    cleaned_path = "."
    model = coremltools.converters.sklearn.convert(
        sklearn_model,
        "dense_input",
        "Identity"
    )
    spec = model.get_spec()

    model.author = "Rooms - https://github.com/st0nedB/rooms"
    model.license = "MIT"
    model.short_description = "This model can be used to predict in which room a device resides based on BLE beacon measurements."
    model.versionString =  "Version 0.1"
    model.input_description["dense_input"] = "Vector of input RSSI"
    model.output_description["Identity"] = "Predicted Room"
    model.save(cleaned_path + "/" + modelName +  ".mlmodel")


def convertCoreML(keras_model, labelbinarizer):
    # modelName for coreML model
    modelName = "rooms_coreml"
    cleaned_path = "."

    class_labels = labelbinarizer.classes_.tolist()
    mlconfig = coremltools.ClassifierConfig(class_labels)

    # load the trained convolutional neural network
    model = coremltools.convert(
                keras_model,
                input_names=["dense_input"],
                classifier_config=mlconfig,
                )


    spec = model.get_spec()

    model.author = "Rooms - https://github.com/st0nedB/rooms"
    model.license = "MIT"
    model.short_description = "This model can be used to predict in which room a device resides based on BLE beacon measurements."
    model.versionString =  "Version 0.1"
    model.input_description["dense_input"] = "Vector of input RSSI"
    model.output_description["Identity"] = "Predicted Room"
    model.save(cleaned_path + "/" + modelName +  ".mlmodel")

def serveHTTPFile(port):
    handler = http.server.SimpleHTTPRequestHandler

    with socketserver.TCPServer(("", port), handler) as httpd:
        logging.warning("Server started at localhost:" + str(port))
        logging.warning("Press CRTL+C to stop...")
        httpd.serve_forever()


if __name__ == "__main__":
    options = get_options()
    logger = set_logging(level=logging.INFO)

    # parse the options
    nbeacon = options.num_beacon
    nepochs = options.num_epochs
    nbatch = options.batch_size
    actfunc = options.activation_function
    servehttp = options.http
    port = options.port

    # load input data from json files
    data, rooms, nsamples = loadData(nbeacon=nbeacon)

    # make a label binarizer object
    lbinarizer = makeLabelBinarizer(rooms)

    # parse the data
    X, Y = parseData(jsondata=data, rooms=rooms, nsamples=nsamples, lb=lbinarizer)

    # split into train-test set
    X_train, X_test, Y_train, Y_test = train_test_split(X, Y, shuffle=True, test_size=0.1)

    # train a SVM classifier
    mlmodel, score = makeSKlearnModel(data=(X_train, X_test, lbinarizer.inverse_transform(Y_train), lbinarizer.inverse_transform(Y_test)), cl2=0.75)
    logging.info("SVM Model accuracy: {:.4f} ".format(score))
    mlmodel, score = makeSKlearnModel(data=(X_train, X_test, lbinarizer.inverse_transform(Y_train), lbinarizer.inverse_transform(Y_test)), cl2=0.875)
    logging.info("SVM Model accuracy: {:.4f} ".format(score))
    mlmodel, score = makeSKlearnModel(data=(X_train, X_test, lbinarizer.inverse_transform(Y_train), lbinarizer.inverse_transform(Y_test)), cl2=1)
    logging.info("SVM Model accuracy: {:.4f} ".format(score))


    convertCoreMLSklearn(sklearn_model=mlmodel)
    # setup and train the model
    #mlmodel = makeModel(inputshape=(X_train.shape[1],), nlabels=len(rooms), actfunc=actfunc, dropout=0.5)

    #mlmodel, score = trainModel(model=mlmodel, X_train=X_train, X_test=X_test, Y_train=Y_train, Y_test=Y_test, nepochs=nepochs, nbatch=nbatch)
    #logging.info("Model loss: {:.4f} \t Model accuracy: {:.4f} ".format(*score))
    #plotConfusionMatrix(ytest=Y, ypred=mlmodel.predict(X), labels=rooms) not working correctly right now

    # save tf.keras model
    #mlmodel.save("mlmodel.h5")

    # convert trained keras model to CoreML model, saved in rooms_coreml.mlmodel
    #convertCoreML(keras_model=mlmodel, labelbinarizer=lbinarizer)

    # serve the file on http, if requested by --http argument
    if servehttp:
        logging.info("Starting http server at port {:d} to serve {:s}".format(port, "rooms_coreml.mlmodel"))
        serveHTTPFile(port=port)
