setwd('WGCNA/')
# 	56 breast cancer cell lines were profiled to identify patterns of gene expression associated with subtype and response to therapeutic compounds.
if(F){
  ## https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE48213
  #wget -c ftp://ftp.ncbi.nlm.nih.gov/geo/series/GSE48nnn/GSE48213/suppl/GSE48213_RAW.tar
  #tar -xf GSE48213_RAW.tar
  #gzip -d *.gz
  ## 首先在GSE48213_RAW目录里面生成tmp.txt文件，使用shell脚本
  # awk '{print FILENAME"\t"$0}' * |grep -v EnsEMBL_Gene_ID >tmp.txt
  ## 然后把tmp.txt导入R语言里面用reshape2处理即可
  a=read.table('GSE48213_RAW/tmp.txt',sep = '\t',stringsAsFactors = F)
  library(reshape2)
  fpkm <- dcast(a,formula = V2~V1)
  rownames(fpkm)=fpkm[,1]
  fpkm=fpkm[,-1]
  colnames(fpkm)=sapply(colnames(fpkm),function(x) strsplit(x,"_")[[1]][1])
  
  library(GEOquery)
  a=getGEO('GSE48213')
  metadata=pData(a[[1]])[,c(2,10,12)]
  datTraits = data.frame(gsm=metadata[,1],
             cellline=trimws(sapply(as.character(metadata$characteristics_ch1),function(x) strsplit(x,":")[[1]][2])),
             subtype=trimws(sapply(as.character(metadata$characteristics_ch1.2),function(x) strsplit(x,":")[[1]][2]))
             )
  save(fpkm,datTraits,file = 'GSE48213-wgcna-input.RData')
}
load('GSE48213-wgcna-input.RData')
library(WGCNA)
## step 1 :
if(T){
  
  fpkm[1:4,1:4]
  head(datTraits)
  
  RNAseq_voom <- fpkm 
  ## 因为WGCNA针对的是基因进行聚类，而一般我们的聚类是针对样本用hclust即可，所以这个时候需要转置
  WGCNA_matrix = t(RNAseq_voom[order(apply(RNAseq_voom,1,mad), decreasing = T)[1:5000],])
  datExpr0 <- WGCNA_matrix  ## top 5000 mad genes
  datExpr <- datExpr0 
  
  ## 下面主要是为了防止临床表型与样本名字对不上
  sampleNames = rownames(datExpr);
  traitRows = match(sampleNames, datTraits$gsm)
  rownames(datTraits) = datTraits[traitRows, 1]
  
}


## step 2 

if(T){
  powers = c(c(1:10), seq(from = 12, to=20, by=2))
  # Call the network topology analysis function
  sft = pickSoftThreshold(datExpr, powerVector = powers, verbose = 5)
  #设置网络构建参数选择范围，计算无尺度分布拓扑矩阵
  png("step2-beta-value.png",width = 800,height = 600)
  # Plot the results:
  ##sizeGrWindow(9, 5)
  par(mfrow = c(1,2));
  cex1 = 0.9;
  # Scale-free topology fit index as a function of the soft-thresholding power
  plot(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
       xlab="Soft Threshold (power)",ylab="Scale Free Topology Model Fit,signed R^2",type="n",
       main = paste("Scale independence"));
  text(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
       labels=powers,cex=cex1,col="red");
  # this line corresponds to using an R^2 cut-off of h
  abline(h=0.90,col="red")
  # Mean connectivity as a function of the soft-thresholding power
  plot(sft$fitIndices[,1], sft$fitIndices[,5],
       xlab="Soft Threshold (power)",ylab="Mean Connectivity", type="n",
       main = paste("Mean connectivity"))
  text(sft$fitIndices[,1], sft$fitIndices[,5], labels=powers, cex=cex1,col="red")
  dev.off()
}

## step3 

if(T){
  net = blockwiseModules(
    datExpr,
    power = sft$powerEstimate,
    maxBlockSize = 6000,
    TOMType = "unsigned", minModuleSize = 30,
    reassignThreshold = 0, mergeCutHeight = 0.25,
    numericLabels = TRUE, pamRespectsDendro = FALSE,
    saveTOMs = TRUE,
    saveTOMFileBase = "AS-green-FPKM-TOM",
    verbose = 3
  )
  table(net$colors) 
}


## step 4 
if(T){
  
  # Convert labels to colors for plotting
  mergedColors = labels2colors(net$colors)
  table(mergedColors)
  moduleColors=mergedColors
  # Plot the dendrogram and the module colors underneath
  png("step4-genes-modules.png",width = 800,height = 600)
  plotDendroAndColors(net$dendrograms[[1]], mergedColors[net$blockGenes[[1]]],
                      "Module colors",
                      dendroLabels = FALSE, hang = 0.03,
                      addGuide = TRUE, guideHang = 0.05)
  dev.off()
  ## assign all of the gene to their corresponding module 
  ## hclust for the genes.
}

if(F){
  #明确样本数和基因
  nGenes = ncol(datExpr)
  nSamples = nrow(datExpr)
  #首先针对样本做个系统聚类
  datExpr_tree<-hclust(dist(datExpr), method = "average")
  par(mar = c(0,5,2,0))
  plot(datExpr_tree, main = "Sample clustering", sub="", xlab="", cex.lab = 2, 
       cex.axis = 1, cex.main = 1,cex.lab=1)
  ## 如果这个时候样本是有性状，或者临床表型的，可以加进去看看是否聚类合理
  #针对前面构造的样品矩阵添加对应颜色
  sample_colors <- numbers2colors(as.numeric(factor(datTraits$subtype)), 
                                  colors = c("white","blue","red","green"),signed = FALSE)
  ## 这个给样品添加对应颜色的代码需要自行修改以适应自己的数据分析项目
  #  sample_colors <- numbers2colors( datTraits ,signed = FALSE)
  ## 如果样品有多种分类情况，而且 datTraits 里面都是分类信息，那么可以直接用上面代码，当然，这样给的颜色不明显，意义不大
  #10个样品的系统聚类树及性状热图
  par(mar = c(1,4,3,1),cex=0.8)
  
  png("sample-subtype-cluster.png",width = 800,height = 600)
  plotDendroAndColors(datExpr_tree, sample_colors,
                      groupLabels = colnames(sample),
                      cex.dendroLabels = 0.8,
                      marAll = c(1, 4, 3, 1),
                      cex.rowText = 0.01,
                      main = "Sample dendrogram and trait heatmap")
  dev.off()
}

## step 5 
## 这一步主要是针对于连续变量，如果是分类变量，需要转换成连续变量方可使用
if(T){
  nGenes = ncol(datExpr)
  nSamples = nrow(datExpr)
  design=model.matrix(~0+ datTraits$subtype)
  colnames(design)=levels(datTraits$subtype)
  moduleColors <- labels2colors(net$colors)
  # Recalculate MEs with color labels
  MEs0 = moduleEigengenes(datExpr, moduleColors)$eigengenes
  MEs = orderMEs(MEs0); ##不同颜色的模块的ME值矩 (样本vs模块)
  moduleTraitCor = cor(MEs, design , use = "p");
  moduleTraitPvalue = corPvalueStudent(moduleTraitCor, nSamples)
  
  sizeGrWindow(10,6)
  # Will display correlations and their p-values
  textMatrix = paste(signif(moduleTraitCor, 2), "\n(",
                     signif(moduleTraitPvalue, 1), ")", sep = "");
  dim(textMatrix) = dim(moduleTraitCor)
  png("step5-Module-trait-relationships.png",width = 800,height = 1200,res = 120)
  par(mar = c(6, 8.5, 3, 3));
  # Display the correlation values within a heatmap plot
  labeledHeatmap(Matrix = moduleTraitCor,
                 xLabels = names(design),
                 yLabels = names(MEs),
                 ySymbols = names(MEs),
                 colorLabels = FALSE,
                 colors = greenWhiteRed(50),
                 textMatrix = textMatrix,
                 setStdMargins = FALSE,
                 cex.text = 0.5,
                 zlim = c(-1,1),
                 main = paste("Module-trait relationships"))
  dev.off()
}


## step 6

if(T){
  # names (colors) of the modules
  modNames = substring(names(MEs), 3)
  geneModuleMembership = as.data.frame(cor(datExpr, MEs, use = "p"));
  ## 算出每个模块跟基因的皮尔森相关系数矩
  ## MEs是每个模块在每个样本里面的
  ## datExpr是每个基因在每个样本的表达量
  MMPvalue = as.data.frame(corPvalueStudent(as.matrix(geneModuleMembership), nSamples));
  names(geneModuleMembership) = paste("MM", modNames, sep="");
  names(MMPvalue) = paste("p.MM", modNames, sep="");
  
  
  
  ## 只有连续型性状才能只有计算
  ## 这里把是否属 Luminal 表型这个变量0,1进行数值化
  Luminal = as.data.frame(design[,3]);
  names(Luminal) = "Luminal"
  geneTraitSignificance = as.data.frame(cor(datExpr, Luminal, use = "p"));
  GSPvalue = as.data.frame(corPvalueStudent(as.matrix(geneTraitSignificance), nSamples));
  names(geneTraitSignificance) = paste("GS.", names(Luminal), sep="");
  names(GSPvalue) = paste("p.GS.", names(Luminal), sep="");
  
  module = "brown"
  column = match(module, modNames);
  moduleGenes = moduleColors==module;
  png("step6-Module_membership-gene_significance.png",width = 800,height = 600)
  #sizeGrWindow(7, 7);
  par(mfrow = c(1,1));
  verboseScatterplot(abs(geneModuleMembership[moduleGenes, column]),
                     abs(geneTraitSignificance[moduleGenes, 1]),
                     xlab = paste("Module Membership in", module, "module"),
                     ylab = "Gene significance for Luminal",
                     main = paste("Module membership vs. gene significance\n"),
                     cex.main = 1.2, cex.lab = 1.2, cex.axis = 1.2, col = module)
  dev.off()
  
}


## step 7 
if(T){
  nGenes = ncol(datExpr)
  nSamples = nrow(datExpr)
  geneTree = net$dendrograms[[1]]; 
  dissTOM = 1-TOMsimilarityFromExpr(datExpr, power = 6); 
  plotTOM = dissTOM^7; 
  diag(plotTOM) = NA; 
  #TOMplot(plotTOM, geneTree, moduleColors, main = "Network heatmap plot, all genes")
  nSelect = 400
  # For reproducibility, we set the random seed
  set.seed(10);
  select = sample(nGenes, size = nSelect);
  selectTOM = dissTOM[select, select];
  # There’s no simple way of restricting a clustering tree to a subset of genes, so we must re-cluster.
  selectTree = hclust(as.dist(selectTOM), method = "average")
  selectColors = moduleColors[select];
  # Open a graphical window
  sizeGrWindow(9,9)
  # Taking the dissimilarity to a power, say 10, makes the plot more informative by effectively changing
  # the color palette; setting the diagonal to NA also improves the clarity of the plot
  plotDiss = selectTOM^7;
  diag(plotDiss) = NA;
  
  png("step7-Network-heatmap.png",width = 800,height = 600)
  TOMplot(plotDiss, selectTree, selectColors, main = "Network heatmap plot, selected genes")
  dev.off()
  
  # Recalculate module eigengenes
  MEs = moduleEigengenes(datExpr, moduleColors)$eigengenes
  ## 只有连续型性状才能只有计算
  ## 这里把是否属 Luminal 表型这个变量0,1进行数值化
  Luminal = as.data.frame(design[,3]);
  names(Luminal) = "Luminal"
  # Add the weight to existing module eigengenes
  MET = orderMEs(cbind(MEs, Luminal))
  # Plot the relationships among the eigengenes and the trait
  sizeGrWindow(5,7.5);
  
  par(cex = 0.9)
  png("step7-Eigengene-dendrogram.png",width = 800,height = 600)
  plotEigengeneNetworks(MET, "", marDendro = c(0,4,1,2), marHeatmap = c(3,4,1,2), cex.lab = 0.8, xLabelsAngle
                        = 90)
  dev.off()
  
  # Plot the dendrogram
  sizeGrWindow(6,6);
  par(cex = 1.0)
  ## 模块的进化树
  png("step7-Eigengene-dendrogram-hclust.png",width = 800,height = 600)
  plotEigengeneNetworks(MET, "Eigengene dendrogram", marDendro = c(0,4,2,0),
                        plotHeatmaps = FALSE)
  dev.off()
  # Plot the heatmap matrix (note: this plot will overwrite the dendrogram plot)
  par(cex = 1.0)
  ## 性状与模块热
  
  png("step7-Eigengene-adjacency-heatmap.png",width = 800,height = 600)
  plotEigengeneNetworks(MET, "Eigengene adjacency heatmap", marHeatmap = c(3,4,2,2),
                        plotDendrograms = FALSE, xLabelsAngle = 90)
  dev.off()
  
}

## step 8 
if(T){
  # Select module
  module = "brown";
  # Select module probes
  probes = colnames(datExpr) ## 我们例子里面的probe就是基因
  inModule = (moduleColors==module);
  modProbes = probes[inModule]; 
}

## step 9 
if(T){
  # Recalculate topological overlap
  TOM = TOMsimilarityFromExpr(datExpr, power = 6); 
  # Select module
  module = "brown";
  # Select module probes
  probes = colnames(datExpr) ## 我们例子里面的probe就是基因
  inModule = (moduleColors==module);
  modProbes = probes[inModule]; 
  ## 也是提取指定模块的基因名
  # Select the corresponding Topological Overlap
  modTOM = TOM[inModule, inModule];
  dimnames(modTOM) = list(modProbes, modProbes)
  ## 模块对应的基因关系矩
  cyt = exportNetworkToCytoscape(
    modTOM,
    edgeFile = paste("CytoscapeInput-edges-", paste(module, collapse="-"), ".txt", sep=""),
    nodeFile = paste("CytoscapeInput-nodes-", paste(module, collapse="-"), ".txt", sep=""),
    weighted = TRUE,
    threshold = 0.02,
    nodeNames = modProbes, 
    nodeAttr = moduleColors[inModule]
  );
}







