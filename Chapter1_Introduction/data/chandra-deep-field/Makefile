# CIAO uses parameter files, which are by default written to a single directories in $HOME
# To avoid collisions, we modify CIAO to write parameter files to unique directories in ./params
CIAO_INIT=source $(CURDIR)/ciao-4.5/bin/ciao.sh -o -q &> /dev/null && export PFILES=$${PFILES/*;/$(shell mkdir -p $(CURDIR)/params && env TMPDIR=$(CURDIR)/params mktemp -d -t ciao);}

all : ciao-4.5 8594 8594_repro 8594_photon_counts.npz

# Create a temporary directory for holding downloads from CIAO installation
downloads:
	mkdir -p $@
	touch $@

# Set up the CIAO software suite to install into this directory
install_params.txt: downloads
	echo "$(CURDIR)/$<" > $@
	echo $(CURDIR) >> $@

# Install the CIAO software suite
ciao-4.5 : install_params.txt
	[ -d $@ ] || ./ciao-install.sh < $<
	[ -d $@ ] && touch $@

# Download a Chandra observation of the Deep Field South
# Found using the HEASARC Website: http://heasarc.gsfc.nasa.gov/cgi-bin/W3Browse/w3browse.pl
# See observations.txt for other observations
8594 : ciao-4.5
	$(CIAO_INIT) && download_chandra_obsid $@	

# For various reasons, it is necessary to reprocess a Chandra observation after downloading it
# See: http://cxc.harvard.edu/ciao/threads/createL2/ for a laundry list of corner cases where this is apparently necessary
%_repro : %
	[ -d $@ ] || $(CIAO_INIT) && chandra_repro $< $@
	[ -d $@ ] && touch $@

%_photon_counts.npz : %_repro
	$(CIAO_INIT) && dmlist "$</*_evt2.fits[events][cols time]" opt=data \
		| tail -n +8 \
		| ./mk_photon_counts_npz.py $@

clean :
	rm -rf *.log downloads install_params.txt ciao-4.5 params
