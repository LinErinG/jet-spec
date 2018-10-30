;
; Notes on codes to perform spectral fits for Sophie's jet work
;

; Questions for Sophie:
; -- Easier to call functions with flare number or time range?  
;		I like flare number better. Sophie agrees.
; -- Which functions do we want included in the fit?  VTH only?  VTH + BPOW?  
;		Yes, these two options.  Add both to the same routine, with keyword(s).
;		-- Probably best to do it once, separately, for each!
; -- Do we want parameters over time, or just for one interval?  
;		We agree that right now we don't need time evolution.
; -- What are the most useful outputs?
;		-- At what energy does the count spectrum equal background?  Decide whether to 
;			save this separately or compute it from saved fit structure.
;
; -- Sophie suggestion:  add time interval to saved file from spex, and have fit routine 
;	check this.  Maybe add more info to file name, too.
;
; Some outstanding tasks/options for the code:
; -- Remove background determination from jet_fit_spex and just use the times that are 
;		now in the filenames.  Do the same for the fit time interval. These two 
;		keywords should be removed entirely from jet_fit_spex.
; -- The saved plots should be made prettier -- colors, better formatting, more labels.
; -- Add option to do VTH only fit, instead of always doing VTH+BPOW.
; -- Add a function to show spectrograms of the detectors, to aid in detector choices.
;		-- Either generate these on the fly, or use Berkeley quicklooks, e.g.:
;	 https://hesperia.gsfc.nasa.gov/rhessi_extras/spectrograms/counts_plots/2012/09/12/hsi_orbit_spec_9dets_20120912_0432.png
; -- Some of these things could be in separate functions/procedures that are run first...
;		-- e.g. time interval / bkgd selection / spectrograms could be done before 
;		   starting the spex routine.
; 		-- May want a routine to auto-generate the flare number.
; -- Need more checks to ensure the options (keywords) set in the two routines are the same.
;		-- As it is, if delta_t or time_range keywords are used, these MUST be set to be 
;		-- the same between the two routine. The file names do not currently track this.
; -- The routines are poorly named, given that they work for any flare, not just jets!
; -- The code could be adapted for Fermi and/or KW.
; -- Currently, the defaults are to just use detector 1.  Use of the code should try more.
; -- 

; Examples:

; Sept 12, 2012 (Example that was used for most of the debugging.  All default settings.)
flare_num = 12091214
jet_make_spex, flare_num
jet_fit_spex, flare_num

; June 30, 2012 (Example using the default of 30 sec around flare peak)
flare_num = 12063050
jet_make_spex, flare_num
jet_fit_spex, flare_num
; Note: an examination of the defaults chosen here show that the default does NOT give 
; the most optimal interval.  It's missing the high-energy component.

; June 30, 2012 (Example of manually setting a larger fit duration, still around the peak)
flare_num = 12063050
jet_make_spex, flare_num, delta_t=60.
jet_fit_spex, flare_num, delta_t=60.
; This *still* misses the high-energy peak!  For this one, we should choose the time 
; interval by hand.

; June 30, 2012 (Example of manually setting the time interval)
flare_num = 12063050
jet_make_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
jet_fit_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
; This is a much better time interval, and gives a good fit.

; June 30, 2012 (Example of manually setting the background time interval, since there 
; are data for quite awhile into the eclipse.)
flare_num = 12063050
jet_make_spex, flare_num, time_range='2012-jun-30 '+['1830','1832'], $
	bkg='2012-jun-30 '+['185032','1900']
jet_fit_spex, flare_num, time_range='2012-jun-30 '+['1830','1832']
; This is a much better time interval, and gives a good fit.

