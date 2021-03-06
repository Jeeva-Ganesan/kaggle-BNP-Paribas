###
#  sandbox for testing Level 2 blending models
###

library(caret)
library(data.table)

source("./src/CommonFunctions.R")

load(paste0(DATA.DIR,"/train_calib_test.RData"))

train.df <- train0.raw[1:100,]

list.of.models <- c("L1_gbm2","L1_nnet1")

createL2FeatureForOneModel <- function(level1.model.dir,df,includeResponse=FALSE){
    #level1.model.dir: model directory for Level 1 model
    #df: training data
    
    # get L1 model name
    model.file.name <- readLines(paste0("./src/",level1.model.dir,"/this_model"))
    
    # get Level 1 model data
    l1.env <- new.env()
    load(paste0("./src/",level1.model.dir,"/",model.file.name),envir = l1.env)
    
    ll <- lapply(l1.env$LEVEL0.MODELS,createLevel1Features,df,includeResponse)
    
    predictors <- do.call(cbind,ll)
    
    #extract only Class_1 probabilities
    class1.names <- grep("Class_1",names(predictors),value = TRUE)
    predictors <- predictors[class1.names]
    
    pred.probs <- predict(l1.env$mdl.fit,newdata=predictors,type="prob")
    
    
    return(as.array(pred.probs$Class_1))
    
}


prepL2FeatureSetX <- function(level1.models,df,includeResponse=TRUE){
    #prepL2FeatureSet
    #level1.models: vector of Level 1 model ids 
    #df: data set to prepare
    force(level1.models)
    
    ll <- lapply(level1.models,createL2FeatureForOneModel,df)
    
    predictors <- do.call(cbind,ll)
    

    
#     ll <- lapply(predictors,function(x){x$predictors})
#     predictors <- do.call(cbind,ll)
#     names(predictors) <- paste(level1.models,"Class_1",sep=".")
    
    
    if (includeResponse) {
       
        response <- factor(ifelse(df$target == 1,"Class_1","Class_0"),
                           levels=c("Class_1","Class_0"))
        ans <- list(predictors=predictors,response=response)
        
    } else {
        
        ans <- list(predictors=predictors)
        
    }
    
    return(ans)
    
}

x <- lapply(list.of.models,prepL2FeatureSetX,train.df,TRUE)
str(x)

# do.call(cbind,lapply(x,function(x){x[[1]]}))


# y <- createL2FeatureForOneModel("L1_nnet1",train.df)
