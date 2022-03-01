#-------------------------------------- CONFIGURATION------------------------------------------
proj_name = "test"         					# e.g.: "ph-analysis-sample-1"
xquest_def_path = "/home/noel/xquest.def"			# run create_configs.sh to get these .def-files
xmm_def_path = "/home/noel/xmm.def"				# and modify them according to the experimental design
xprophet_def_path = "/home/noel/xproph.def"
raw_path = "/home/noel/Documents/RAW"				# path to raw-files
								# make sure u store them somewhere in 
								# /home/username/.../ NOT in e.g. /usr/share/ !   
								# WARNING: ALL FILES IN THIS DIR WILL BE USED FOR ANALYSIS
#-----------------------------------------------------------------------------------------------

work_dir = os.environ["HOME"] + "/xquest/analysis/" + proj_name
raw = raw_path.split(os.environ["HOME"])[1]
if raw[-1] == "/":
	raw = raw[:-1]
samples = os.listdir(os.environ["HOME"] + "/" + raw)
mz_samples = [filename.replace(".raw", ".mzXML") for filename in samples]
samples_base = [filename.replace(".raw", "") for filename in samples]

with open (xquest_def_path, 'rt') as xq_file:
    for line in xq_file: 
        if "database" in line and "decoy" not in line:
        	fasta_path = line.replace("database", "").strip()
        	fasta_name = fasta_path.split("/")[-1]
        	break

xq_postfixes_per_sample_main = ["matched", "matcheddir", "matched.txt", 
								"matched.txt_isopairs.xls", "matched_isotopepairs.txt"]
xq_files_per_sample_main_dir = ["inclusionlist.xls", "runxq0.sh"]
xq_files_per_sample_nested = ["xquest.def", "xquest.xml", ""+ fasta_name + "", "db/"+ fasta_name + "", 
							  "db/"+ fasta_name + "_ion.db", "db/"+ fasta_name + "_index.stat",
							  "db/"+ fasta_name + "_peps.db", "db/"+ fasta_name + "_info.db", 
							  "db/"+ fasta_name + "_peptides.txt"]
xq_postfixes_per_sample_nested= ["matched.stat", "matched.spec.xml", "matched.progress", "matched.stat.done"]

shell("""
	case ":$PATH:" in
	  *:/usr/local/share/xquest/V2.1.5/xquest/bin:*) printf "PATH correctly set.\n\n"
        ;;
	  *)  printf "Setting PATH... "
	      cp $HOME/.bashrc $HOME/.bashrc.bak
	      echo "export PATH=$PATH:/usr/local/share/xquest/V2.1.5/xquest/bin" >> $HOME/.bashrc
	      source $HOME/.bashrc
	      printf "Done.\n\n"
	    ;;
	esac
	"""
	)

rule copy_configs:
	input:
		xq=xquest_def_path,
		xmm=xprophet_def_path,
		xp=xmm_def_path
	params:
		work_dir=work_dir,
		result_dir=work_dir + "/results/" + proj_name 
	output:
		work_dir + "/xquest.def",
		work_dir + "/xmm.def",
		work_dir + "/results/" + proj_name + "/xproph.def"
	shell:
		"""
		mkdir -p $HOME/xquest/{{results,analysis/{params.directory}/db}}
		sed -i "s#/path/to/decoy-database/database.fasta#$HOME/xquest/analysis/{params.directory}/db/database_decoy.fasta#g" {input.xq}
		cp {input.xq} {params.work_dir}
		cp {input.xmm} {params.work_dir}
		cp {input.xp} {params.result_dir}
		"""


rule convert_RAW_to_MzXML:
	input:
		os.environ["HOME"] + raw + "/{sample}.raw"
	params:
		raw = raw,
		work_dir = work_dir,
		proj_name = proj_name
	output:
		work_dir + "/mzxml/{sample}.mzXML"
	shell:
		"""
		mkdir -p {params.work_dir}/mzxml
		sudo docker run -v $HOME:/hm chambm/pwiz-skyline-i-agree-to-the-vendor-licenses wine \
					msconvert /hm/{params.raw}/{sample}.raw --mzXML --32 -o /hm/xquest/analysis/{params.proj_name}/mzxml/
		sudo chown $USER {output}
		"""


rule manage_mzxml:
	input:
		expand(work_dir + "/mzxml/{sample}", sample=mz_samples)
	params:
		work_dir = work_dir
	output:
		work_dir + "/files"
	shell:
		"""
		ls {params.work_dir}/mzxml/ | sed 's/\\(.*\\)\\..*/\\1/' > {params.work_dir}/files
		"""


rule manage_db:
	input:
		work_dir + "/xquest.def",
		work_dir + "/xmm.def",
		work_dir + "/results/" + proj_name + "/xproph.def"
	params: 
		directory=proj_name,
		fasta_path=fasta_path
	output:
		work_dir + "/db/database_decoy.fasta",
		symlink_fasta = work_dir + "/db/"+ fasta_name
	shell:
		"""
		mkdir -p $HOME/xquest/{{results,analysis/{params.directory}/db}}

		cd $HOME/xquest/analysis/{params.directory}/
		ln -sf {params.fasta_path} {output.symlink_fasta}
		xdecoy.pl -db {output.symlink_fasta} -out db/database_decoy.fasta
		"""
		

rule xquest_configure_search:
	input:
		work_dir + "/xmm.def",
		work_dir + "/xquest.def",
		work_dir + "/files",
		work_dir + "/db/"+ fasta_name,
		expand(work_dir + "/mzxml/{filename}", filename=mz_samples)
	params: 
		work_dir
	output:
		expand(work_dir + "/{filename}/{filename}.mzXML", filename=samples_base),
		expand(work_dir + "/{filename}/MASTER_RUN/MASTER_RUN.txt", filename=samples_base),
		expand(work_dir + "/{filename}/xmm.def", filename=samples_base),
		expand(work_dir + "/{filename}/xquest.def", filename=samples_base)
	run:
		import shutil

		for sample in samples_base:
			shutil.rmtree(work_dir + "/" + sample)
		shell(
		"""
		cd {params}
		printf "Configuring the search with pQuest.pl...\n\n"
		pQuest.pl -list files -path {params}/mzxml/
		"""
		)


rule xquest_run_search:
	input:
		work_dir + "/files",
		expand(work_dir + "/{filename}/{filename}.mzXML", filename=samples_base),
		expand(work_dir + "/{filename}/MASTER_RUN/MASTER_RUN.txt", filename=samples_base),
		expand(work_dir + "/{filename}/xmm.def", filename=samples_base),
		expand(work_dir + "/{filename}/xquest.def", filename=samples_base)	
	params: 
		work_dir
	output:
		expand(work_dir + "/{filename}/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_main),
		expand(work_dir + "/{filename}/{file}", file=xq_files_per_sample_main_dir, filename=samples_base),
		expand(work_dir + "/{filename}/{filename}_matched/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_nested),
		expand(work_dir + "/{filename}/{filename}_matched/{file}", filename=samples_base, file=xq_files_per_sample_nested),
		work_dir + "/resultdirectories_fullpath",
		work_dir + "/resultdirectories"
	shell:
		"""
		cd {params}
		printf "Running the search...\n\n"
		runXquest.pl -list files -xmlmode -pseudosh
		printf "Running the search... Done.\n\n"
		"""


rule merge_search_results:
	input:
		work_dir + "/files",
		work_dir + "/xmm.def",
		work_dir + "/xquest.def",
		expand(work_dir + "/{filename}/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_main),
		expand(work_dir + "/{filename}/{file}", file=xq_files_per_sample_main_dir, filename=samples_base),
		expand(work_dir + "/{filename}/{filename}_matched/{filename}_{postfix}", filename=samples_base, postfix=xq_postfixes_per_sample_nested),
		expand(work_dir + "/{filename}/{filename}_matched/{file}", filename=samples_base, file=xq_files_per_sample_nested),
		work_dir + "/resultdirectories_fullpath",
		work_dir + "/resultdirectories"
	params: 
		dir=proj_name, 
		work_dir=work_dir
	output:
		work_dir + "/results/" + proj_name + "/merged_xquest.xml"
	run:
		for sample in samples_base:
			path = work_dir + "/" + sample + "/" + sample + "_matcheddir"
			if not os.path.exists(path):
				os.makedirs(path)
		shell(
			"""
			cd {params.work_dir}
			printf "Merging result files...\n"
			mergexml.pl -list resultdirectories_fullpath -resdir {params.work_dir}/results/{params.dir}
			printf "Merging result files... Done.\n\n"
			"""
			)


rule annotate_results:
	input: 
		work_dir + "/merged_xquest.xml"
	params:
		result_dir=work_dir + "/results/" + proj_name
	output: 
		work_dir + "/results/" + proj_name + "/annotated_xquest.xml"
	shell:
		"""
		cd {params.result_dir}
		printf "Annotating results..."
		annotatexml.pl -xmlfile merged_xquest.xml -out annotated_xquest.xml -native -v
		printf "Annotating results... Done.\n\n"
		"""


rule xprophet_configure:
	input:
		work_dir + "/results/" + proj_name + "/merged_xquest.xml"
	params:
		result_dir=work_dir + "/results/" + proj_name
	output:
		work_dir + "/results/" + proj_name + "/xproph.def"
	shell:
		"""
		cd {params.result_dir}
		printf "Configuring xProphet analysis...\n"
		xprophet.pl
		printf "Configuring xProphet analysis... Done.\n\n"
		"""


rule xprophet_run:
	input:
		work_dir + "/results/" + proj_name + "/xproph.def"
	params:
		result_dir=work_dir + "/results/" + proj_name
	output:
		work_dir + "/results/" + proj_name + "/xquest.xml"
	shell:
		"""
		cd {params.result_dir}
		printf "Running xProphet...\n"
		xprophet.pl -in annotated_xquest.xml -out xquest.xml
		"""


rule all:
	input:
		work_dir + "/results/" + proj_name + "/xquest.xml"
	params:
		result_dir=work_dir + "/results/" + proj_name
	shell:
		"""
		printf "Copying results to the web server...\n"
		ln -sf {params.result_dir} /usr/local/share/xquest/results/
		printf "Done.\n\n"
		"""

