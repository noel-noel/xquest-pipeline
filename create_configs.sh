cp /usr/local/share/xquest/deffiles/xmm.def . 
cp /usr/local/share/xquest/deffiles/xquest.def .
cp /usr/local/share/xquest/deffiles/Snakefile .

case ":$PATH:" in
  *:/usr/local/share/xquest/V2.1.5/xquest/bin:*) printf "PATH correctly set.\n\n"
                                      ;;
  *)  printf "Setting PATH... "
      export PATH=$PATH:/usr/local/share/xquest/V2.1.5/xquest/bin
      ;;
esac
xprophet.pl
