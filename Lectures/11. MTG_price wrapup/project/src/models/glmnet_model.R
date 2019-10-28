#load in libraries
library(data.table)
library(caret)
library(Metrics)
library(glmnet)
library(plotmo)
library(lubridate)



#read in data, notice the path will always look like this because the assumed working directory is the repo level folder
train<-fread("./project/volume/data/interim/train_v1.csv")
test<-fread("./project/volume/data/interim/test_v1.csv")
example_sub<-fread("./project/volume/data/raw/example_submission.csv")

##########################
# Prep Data for Modeling #
##########################

# make train and test have the same columns
test$future_price<-0

year_num<-as.numeric(as.factor(year(as_date(train$current_date))))

# subset out only the columns to model

drops<- c('id','future_date','current_date')
train<-train[, !drops, with = FALSE]
test<-test[, !drops, with = FALSE]

#save the response var because dummyVars will remove
train_y<-train$future_price


# work with dummies

dummies <- dummyVars(future_price ~ ., data = train)
train<-predict(dummies, newdata = train)
test<-predict(dummies, newdata = test)

train<-data.table(train)
test<-data.table(test)



########################
# Use cross validation #
########################




train<-as.matrix(train)

gl_model<-cv.glmnet(train, train_y, alpha = 1,family="gaussian",foldid = year_num,nfolds = length(unique(year_num)))

plot(gl_model)

bestlam<-gl_model$lambda.min



####################################
# fit the model to all of the data #
####################################


#now fit the full model

#fit a logistic model
gl_model<-glmnet(train, train_y, alpha = 1,family="gaussian")

plot_glmnet(gl_model)

#save model
saveRDS(gl_model,"./project/volume/models/gl_model.model")

test<-as.matrix(test)

#use the full model
pred<-predict(gl_model,s=bestlam, newx = test)

#########################
# make a submision file #
#########################


#our file needs to follow the example submission file format.
#we need the rows to be in the correct order

example_sub$future_price<-pred


#now we can write out a submission
fwrite(example_sub,"./project/volume/data/processed/submit_17.csv")