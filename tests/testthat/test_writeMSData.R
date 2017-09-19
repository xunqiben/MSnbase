test_that("writeMSData works", {
    ## using the onDisk data.
    odf <- tmt_erwinia_on_disk
    ## 1) Filter MS level 1, write, read and compare with tmt_erwinia_in_mem_ms1
    odf_out <- filterMsLevel(odf, msLevel = 1)
    out_file <- paste0(tempfile(), ".mzML")
    MSnbase:::.writeSingleMSData(odf_out, file = out_file,
                                 outformat = "mzml", copy = TRUE)
    odf_in <- readMSData(out_file, mode = "onDisk")
    ## Some stuff is different, i.e. totIonCurrent, basePeakMZ, basePeakIntensity
    expect_equal(unname(rtime(odf_in)), unname(rtime(tmt_erwinia_in_mem_ms1)))
    expect_equal(unname(mz(odf_in)), unname(mz(tmt_erwinia_in_mem_ms1)))
    expect_equal(unname(intensity(odf_in)),
                 unname(intensity(tmt_erwinia_in_mem_ms1)))
    ## feature data should be the same, expect spIdx, seqNum, spectrum and the
    ## columns re-calculated prior to saving.
    fd_out <- fData(odf_out)
    fd_in <- fData(odf_in)
    not_equal <- c("spIdx", "seqNum", "totIonCurrent", "basePeakMZ",
                   "basePeakIntensity", "spectrum")
    check_cols <- colnames(fd_out)[!(colnames(fd_out) %in% not_equal)]
    rownames(fd_out) <- NULL
    rownames(fd_in) <- NULL
    expect_equal(fd_in[, check_cols], fd_out[, check_cols])
    ## 2) MS level 2, mzXML
    out_file <- paste0(tempfile(), ".mzXML")
    odf_out <- filterMsLevel(odf, msLevel = 2)
    expect_warning(
        MSnbase:::.writeSingleMSData(odf_out, file = out_file,
                                     outformat = "mzxml", copy = TRUE)
    )
    odf_in <- readMSData(out_file, mode = "onDisk")
    ## retention time is saved with less precision in mzXML
    expect_true(all.equal(unname(rtime(odf_in)),
                          unname(rtime(tmt_erwinia_in_mem_ms2)),
                          tolerance = 1e4))
    expect_equal(unname(mz(odf_in)), unname(mz(tmt_erwinia_in_mem_ms2)))
    expect_equal(unname(intensity(odf_in)),
                 unname(intensity(tmt_erwinia_in_mem_ms2)))
    ## Ensure that precursor data is preserved.
    fd_out <- fData(odf_out)
    fd_in <- fData(odf_in)
    rownames(fd_out) <- NULL
    rownames(fd_in) <- NULL
    ## Also some additional columns are different for mzXML output.
    check_cols <- colnames(fd_out)[!(colnames(fd_out) %in%
                                     c(not_equal, "retentionTime",
                                       "precursorScanNum", "acquisitionNum",
                                       "injectionTime", "spectrumId"))]
    expect_equal(fd_out[, check_cols], fd_in[, check_cols])
    ## Again force check:
    expect_equal(unname(precursorCharge(odf_out)),
                 unname(precursorCharge(odf_in)))
    expect_equal(unname(precursorMz(odf_out)),
                 unname(precursorMz(odf_in)))
    expect_equal(unname(precursorIntensity(odf_out)),
                 unname(precursorIntensity(odf_in)))

    ## Write two files.
    out_path <- tempdir()
    out_file <- paste0(out_path, c("/a.mzML", "/b.mzML"))
    MSnbase:::.writeMSData(microtofq_on_disk_ms1, files = out_file,
                           copy = FALSE)
    odf_in <- readMSData(out_file, mode = "onDisk")
    expect_equal(unname(rtime(odf_in)), unname(rtime(microtofq_in_mem_ms1)))
    expect_equal(spectra(odf_in), spectra(microtofq_in_mem_ms1))
    ## Providing software_processing.
    odf <- extdata_mzXML_on_disk
    out_file <- paste0(out_path, "/mzXML.mzML")
    MSnbase:::.writeMSData(x = odf, files = out_file,
                 software_processing = c("dummysoft", "0.0.1", "MS:1000035"))
    odf_in <- readMSData(out_file, mode = "onDisk")
    expect_equal(unname(rtime(odf)), unname(rtime(odf_in)))
    expect_equal(unname(mz(odf)), unname(mz(odf_in)))
    expect_equal(unname(intensity(odf)), unname(intensity(odf_in)))
})

test_that(".pattern_to_cv works", {
    ## Not found.
    expect_equal(.pattern_to_cv("unknown"), "MS:-1")
    expect_equal(.pattern_to_cv("peak picking"), "MS:1000035")
    expect_equal(.pattern_to_cv("centroid"), "MS:1000035")    
    expect_equal(.pattern_to_cv("Alignment/retention time adjustment"),
                 "MS:1000745")
})

test_that(".guessSoftwareProcessing works", {
    ## filterMsLevel: Filter: select MS level(s)
    odf_proc <- filterMsLevel(tmt_erwinia_on_disk, msLevel = 1)
    res <- .guessSoftwareProcessing(odf_proc)
    expect_equal(res[[1]][1], "MSnbase")
    expect_equal(res[[1]][2], paste0(packageVersion("MSnbase"), collapse = "."))
    expect_equal(res[[1]][3], "MS:1001486")
    ## clean: Spectra cleaned NO CV YET
    ## bin: Spectra binned: NO CV YET
    ## removePeaks: Curves <= t set to '0': NO CV YET
    odf_proc <- removePeaks(odf_proc)
    res <- .guessSoftwareProcessing(odf_proc)
    expect_equal(res[[1]][3], "MS:1001486")
    expect_equal(length(res[[1]]), 3)
    ## normalise: Spectra normalised
    odf_proc <- normalise(odf_proc)
    res <- .guessSoftwareProcessing(odf_proc)
    expect_equal(length(res[[1]]), 4)
    expect_equal(res[[1]][3], "MS:1001486")
    expect_equal(res[[1]][4], "MS:1001484")
    ## pickPeaks: Spectra centroided
    odf_proc <- pickPeaks(odf_proc)
    res <- .guessSoftwareProcessing(odf_proc)
    expect_equal(length(res[[1]]), 5)
    expect_equal(res[[1]][5], "MS:1000035")
    ## smooth: Spectra smoothed
    odf_proc <- smooth(odf_proc)
    res <- .guessSoftwareProcessing(odf_proc)
    expect_equal(length(res[[1]]), 6)
    expect_equal(res[[1]][6], "MS:1000542")
    ## filterRt: Filter: select retention time
    odf_proc <- filterRt(odf_proc, rt = c(200, 600))
    res <- .guessSoftwareProcessing(odf_proc)
    expect_equal(length(res[[1]]), 7)
    expect_equal(res[[1]][7], "MS:1001486")
    ## filterMz: FilteR: trim MZ
    ## filterFile: Filter: select file(s)
    ## filterAcquisitionNum: Filter: select by
    ## filterEmptySpectra: Removed XXX empty spectra
    ## And with providing in addition other processings.
    res <- .guessSoftwareProcessing(odf_proc, c("other_soft", "43.2.1"))
    expect_equal(res[[1]][7], "MS:1001486")
    expect_equal(res[[2]], c("other_soft", "43.2.1"))
})


test_that("write,OnDiskMSnExp works", {
    out_path <- tempdir()
    out_file <- paste0(out_path, c("/a2.mzML", "/b2.mzML"))
    write(microtofq_on_disk_ms1, files = out_file, copy = TRUE)
    odf_in <- readMSData(out_file, mode = "onDisk")
    expect_equal(unname(rtime(odf_in)), unname(rtime(microtofq_in_mem_ms1)))
    expect_equal(spectra(odf_in), spectra(microtofq_in_mem_ms1))

    ## Write MS1 and MS2
    out_file <- paste0(tempfile(), ".mzML")
    out_data <- tmt_erwinia_on_disk
    write(out_data, file = out_file)
    in_data <- readMSData(out_file, mode = "onDisk")
    expect_equal(rtime(out_data), rtime(in_data))
    ## Columns expected to be different:
    not_equal <- c("totIonCurrent", "basePeakMZ", "basePeakIntensity")
    check_cols <- !(colnames(fData(out_data)) %in% not_equal)
    expect_equal(fData(out_data)[, check_cols], fData(in_data)[, check_cols])
})

test_that("write,MSnExp works", {
    out_path <- tempdir()
    out_file <- paste0(out_path, c("/a3.mzML", "/b3.mzML"))
    write(microtofq_in_mem_ms1, files = out_file, copy = TRUE)
    odf_in <- readMSData(out_file, mode = "onDisk")
    expect_equal(unname(rtime(odf_in)), unname(rtime(microtofq_in_mem_ms1)))
    expect_equal(spectra(odf_in), spectra(microtofq_in_mem_ms1))

    out_file <- paste0(out_path, c("/mzxml3.mzML"))
    write(extdata_mzXML_in_mem_ms2, files = out_file, copy = FALSE)
    odf_in <- readMSData(out_file, mode = "inMem")
    ## Check that main data is the same
    expect_equal(unname(rtime(odf_in)), unname(rtime(extdata_mzXML_in_mem_ms2)))
    expect_equal(unname(mz(odf_in)), unname(mz(extdata_mzXML_in_mem_ms2)))
    expect_equal(unname(intensity(odf_in)),
                 unname(intensity(extdata_mzXML_in_mem_ms2)))
    ## Check that header is the same
    expect_equal(unname(precursorMz(odf_in)),
                 unname(precursorMz(extdata_mzXML_in_mem_ms2)))
    expect_equal(unname(precursorCharge(odf_in)),
                 unname(precursorCharge(extdata_mzXML_in_mem_ms2)))
    expect_equal(unname(precursorIntensity(odf_in)),
                 unname(precursorIntensity(extdata_mzXML_in_mem_ms2)))

    in_file <- system.file(package = "msdata", 
                           "proteomics/MS3TMT10_01022016_32917-33481.mzML.gz")
    data_out <- readMSData(in_file, msLevel = 3, mode = "inMem")
    out_file <- paste0(tempfile(), ".mzML")
    write(data_out, file = out_file, outformat = "mzml", copy = TRUE)
    data_in <- readMSData(out_file, mode = "inMem", msLevel = 3)
    expect_equal(rtime(data_in), rtime(data_out))
    expect_equal(mz(data_in), mz(data_out))
    expect_equal(intensity(data_in), intensity(data_out))
    expect_equal(precursorCharge(data_in), precursorCharge(data_out))
    expect_equal(precursorMz(data_in), precursorMz(data_out))
    expect_equal(precursorIntensity(data_in), precursorIntensity(data_out))
})