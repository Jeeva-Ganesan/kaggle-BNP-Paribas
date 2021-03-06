###
#  train ensemble model by calculating weight factors
###


library(caret)
library(nnet)
library(data.table)

# import global variabels and common functions
source("./src/CommonFunctions.R")
WORK.DIR <- "./src/L2_nnet1"

# get training data for calibration
# L1_gbm2
load("./src/L1_gbm2/data_for_level2_optimization.RData")
calib.gbm2 <- calib.pred.probs
test.gbm2 <- test.pred.probs

# L1_nnet1
load("./src/L1_nnet1/data_for_level2_optimization.RData")
calib.nnet1 <- calib.pred.probs
test.nnet1 <- test.pred.probs

# L1_xtc1
load("./src/L1_xtc1/data_for_level2_optimization.RData")
calib.xtc1 <- calib.pred.probs
test.xtc1 <- test.pred.probs

# combine Level 1 Calibration data
train.data <- list()
train.data$predictors <- cbind(gbm2=calib.gbm2[,"Class_1"],
                               nnet1=calib.nnet1[,"Class_1"],
                               xtc1=calib.xtc1[,Class_1])

train.data$response = calib.gbm2$target

# combine Level 1 Calibration data
test.data <- list()
test.data$predictors <- cbind(gbm2=test.gbm2[,"Class_1"],
                               nnet1=test.nnet1[,"Class_1"],
                              xtc1=test.xtc1[,Class_1])

test.data$response = test.gbm2$target

#
# use Neural net to blend results
#

# set caret training parameters
CARET.TRAIN.PARMS <- list(method="nnet")   # Replace MODEL.METHOD with appropriate caret model

CARET.TUNE.GRID <-  NULL  # NULL provides model specific default tuning parameters

# user specified tuning parameters
#CARET.TUNE.GRID <- expand.grid(nIter=c(100))

# model specific training parameter
CARET.TRAIN.CTRL <- trainControl(method="repeatedcv",
                                 number=5,
                                 repeats=1,
                                 verboseIter=FALSE,
                                 classProbs=TRUE,
                                 summaryFunction=caretLogLossSummary)

CARET.TRAIN.OTHER.PARMS <- list(trControl=CARET.TRAIN.CTRL,
                                maximize=FALSE,
                                tuneGrid=CARET.TUNE.GRID,
                                tuneLength=5,
                                metric="LogLoss")

MODEL.SPECIFIC.PARMS <- list(verbose=FALSE) #NULL # Other model specific parameters

PREPARE.MODEL.DATA <- function(data){return(data)}  #default data prep
PREPARE.MODEL.DATA <- prepL1FeatureSet1

MODEL.COMMENT <- "Neural net blending for Level2"

# force recording model flag
FORCE_RECORDING_MODEL <- FALSE

library(doMC)
registerDoMC(cores = 7)

# library(doSNOW)
# cl <- makeCluster(5,type="SOCK")
# registerDoSNOW(cl)
# clusterExport(cl,list("logLossEval"))

# train the model
Sys.time()
set.seed(825)

time.data <- system.time(mdl.fit <- do.call(train,c(list(x=train.data$predictors,
                                                         y=train.data$response),
                                                    CARET.TRAIN.PARMS,
                                                    MODEL.SPECIFIC.PARMS,
                                                    CARET.TRAIN.OTHER.PARMS)))

time.data
mdl.fit
# stopCluster(cl)

# prepare data for training
pred.probs <- predict(mdl.fit,newdata = test.data$predictors,type = "prob")

score <- logLossEval(pred.probs[,1],test.data$response)
score

#
# record Model performance
#

# record Model performance
modelPerf.df <- read.delim(paste0(WORK.DIR,"/model_performance.tsv"),
                           stringsAsFactors=FALSE)
# determine if score improved
improved <- ifelse(score < min(modelPerf.df$score),"Yes","No")

recordModelPerf(paste0(WORK.DIR,"/model_performance.tsv"),
                mdl.fit$method,
                time.data,
                train.data$predictors,
                score,
                improved=improved,
                bestTune=flattenDF(mdl.fit$bestTune),
                tune.grid=flattenDF(CARET.TUNE.GRID),
                model.parms=paste(names(MODEL.SPECIFIC.PARMS),
                                  as.character(MODEL.SPECIFIC.PARMS),
                                  sep="=",collapse=","),
                comment=MODEL.COMMENT)

modelPerf.df <- read.delim(paste0(WORK.DIR,"/model_performance.tsv"),
                           stringsAsFactors=FALSE)


#display model performance record for this run
tail(modelPerf.df[,1:10],1)

# if last score recorded is better than previous ones save model object
last.idx <- length(modelPerf.df$score)
if (last.idx == 1 || improved == "Yes" || FORCE_RECORDING_MODEL) {
    cat("found improved model, saving...\n")
    flush.console()
    #yes we have improvement or first score, save generated model
    file.name <- paste0("model_",mdl.fit$method,"_",modelPerf.df$date.time[last.idx],".RData")
    file.name <- gsub(" ","_",file.name)
    file.name <- gsub(":","_",file.name)
    
    save(mdl.fit,file=paste0(WORK.DIR,"/",file.name))
    
    # estalish pointer to current model
    writeLines(file.name,paste0(WORK.DIR,"/this_model"))
} else {
    cat("no improvement!!!\n")
    flush.console()
}

