import java.io.*;
import Jama.Matrix;

public interface Block {

  enum Block_t { DENSE, LOW_RANK, HIERARCHICAL }

  public abstract int getRowDimension();

  public abstract int getColumnDimension();

  public abstract Block_t getType();
		
  public abstract Dense toDense();

  public abstract LowRank toLowRank();

  public abstract LowRankBasic toLowRankBasic();

  public abstract Hierarchical castHierarchical();

  public abstract H2Matrix castH2Matrix();

  public abstract void setAccumulator(LowRankBasic accm);

  public abstract LowRankBasic getAccumulator();

  public abstract double compare (Matrix m);

  public abstract double getCompressionRatio ();

  public abstract double getCompressionRatioNoBasis ();

  public abstract String structure ();

  public abstract Block getrf ();

  public abstract Block trsm (Block b, boolean lower);
  
  public abstract Block gemm (Block a, Block b, double alpha, double beta);

  public abstract Block plusEquals (Block b);

  public abstract Block scalarEquals (double s);

  public abstract Block times (Block b);

  public abstract Block accum (LowRankBasic accm);

  public abstract Block copyBlock ();

  public abstract void loadBinary (InputStream stream) throws IOException;

  public abstract void writeBinary (OutputStream stream) throws IOException;

  public abstract void print (int w, int d);

  public static Block readStructureFromFile (BufferedReader reader) throws IOException {
    String str = reader.readLine();
    String[] args = str.split("\\s+");
    int m = Integer.parseInt(args[1]);
    int n = Integer.parseInt(args[2]);

    if (str.startsWith("D")) {
      return new Dense(m, n);
    }
    else if (str.startsWith("LR")) {
      int r = Integer.parseInt(args[3]);
      return new LowRank(m, n, r);
    }
    else if (str.startsWith("H")) {
      Hierarchical h = new Hierarchical(m, n);

      for (int i = 0; i < m; i++) {
        for (int j = 0; j < n; j++)
        { h.setElement(i, j, readStructureFromFile(reader)); }
      }

      return h;
    }
    else
    { return null; } 

  }

  public static Block readFromFile (String name) {
    Block b = null;
    try (FileReader fileS = new FileReader("bin/" + name + ".struct")) {
      BufferedReader reader = new BufferedReader(fileS);
      b = readStructureFromFile(reader);
      reader.close();
    }
    catch (IOException e) {
      PsplHMatrixPack.errorOut(e.getMessage());
    }

    if (b != null) {
      try (FileInputStream fileB = new FileInputStream("bin/" + name + ".bin")) {
        BufferedInputStream stream = new BufferedInputStream(fileB);
        b.loadBinary(stream);
      }
      catch (IOException e) {
        PsplHMatrixPack.errorOut(e.getMessage());
      }
    }
    return b;
  }

  public default void writeToFile (String name) {
    File directory = new File("bin");
    if (!directory.exists())
    { directory.mkdir(); }
    
    try (BufferedWriter writer = new BufferedWriter(new FileWriter("bin/" + name + ".struct"))) {
      String struct = structure();
      writer.write(struct);
      writer.flush();
    }
    catch (IOException e) {
      PsplHMatrixPack.errorOut(e.getMessage());
    }

    try (BufferedOutputStream stream = new BufferedOutputStream(new FileOutputStream("bin/" + name + ".bin"))) {
      writeBinary(stream);
      stream.flush();
    }
    catch (IOException e) {
      PsplHMatrixPack.errorOut(e.getMessage());
    }
  }

}
