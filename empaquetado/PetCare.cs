// Instala y abre PetCare sin que el usuario tenga que saber nada de código.
//
// Este archivo se compila dos veces (ver construir.ps1):
//  - Sin nada adentro: es el programa que queda instalado y que abre el acceso directo.
//  - Con PetCare.zip adentro: es el PetCare.exe que se envía. Lo descomprime, crea el
//    acceso directo en el escritorio y abre el programa instalado.
//
// Se compila con el csc.exe que trae Windows, así que usa C# 5.

using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Windows.Forms;

static class Programa
{
    public const string RECURSO = "PetCare.zip";
    static Mutex abierto;

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        bool esInstalador = Assembly.GetExecutingAssembly().GetManifestResourceInfo(RECURSO) != null;
        if (esInstalador)
        {
            Application.Run(new VentanaInstalador(Opcion(args, "/destino:")));
            return;
        }

        // Si ya está abierto, un segundo doble clic solo muestra la página.
        bool soyElPrimero;
        abierto = new Mutex(true, "PetCare_abierto", out soyElPrimero);
        string carpeta = AppDomain.CurrentDomain.BaseDirectory;
        if (!soyElPrimero)
        {
            string puerto = Path.Combine(carpeta, "puerto.txt");
            if (File.Exists(puerto)) AbrirNavegador(File.ReadAllText(puerto).Trim());
            return;
        }
        Application.Run(new VentanaPrincipal(carpeta, !args.Contains("/sin-navegador")));
    }

    static string Opcion(string[] args, string nombre)
    {
        string a = args.FirstOrDefault(x => x.StartsWith(nombre));
        return a == null ? null : a.Substring(nombre.Length);
    }

    public static void AbrirNavegador(string puerto)
    {
        Process.Start("http://127.0.0.1:" + puerto + "/");
    }
}

/** Base de las dos ventanas: título, mensaje y barra de progreso. */
class VentanaBase : Form
{
    protected readonly Label estado = new Label();
    protected readonly ProgressBar barra = new ProgressBar();

    protected VentanaBase(int alto)
    {
        Text = "PetCare";
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(460, alto);
        BackColor = Color.White;
        Font = new Font("Segoe UI", 10f);
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

        Controls.Add(new Label
        {
            Text = "PetCare",
            Font = new Font("Georgia", 22f),
            ForeColor = Color.FromArgb(0x14, 0x55, 0x4C),
            Location = new Point(24, 16),
            AutoSize = true,
        });
        estado.Location = new Point(26, 66);
        estado.Size = new Size(410, 48);
        Controls.Add(estado);
        barra.Location = new Point(26, 118);
        barra.Size = new Size(408, 14);
        barra.Style = ProgressBarStyle.Marquee;
        Controls.Add(barra);
    }

    /** Los trabajos largos corren aparte; solo la ventana puede tocar la ventana. */
    protected void EnVentana(Action accion)
    {
        if (IsDisposed) return;
        try { BeginInvoke(accion); } catch (InvalidOperationException) { }
    }

    protected void Mensaje(string texto)
    {
        EnVentana(() => estado.Text = texto);
    }

    protected void Trabajar(Action trabajo)
    {
        Thread hilo = new Thread(() =>
        {
            try { trabajo(); }
            catch (Exception e) { Fallo(e.Message); }
        });
        hilo.IsBackground = true;
        hilo.Start();
    }

    protected virtual void Fallo(string detalle)
    {
        EnVentana(() =>
        {
            barra.Visible = false;
            estado.ForeColor = Color.FromArgb(0xB0, 0x2A, 0x2A);
            estado.Text = "No se pudo abrir PetCare. " + detalle;
        });
    }
}

class VentanaInstalador : VentanaBase
{
    readonly string destino;
    readonly bool enPrueba;

    public VentanaInstalador(string destinoPedido) : base(150)
    {
        // Con /destino (solo para probarlo) no toca la carpeta real ni el escritorio.
        enPrueba = destinoPedido != null;
        destino = destinoPedido ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "PetCare");
        // PostgreSQL no logra crear la base si la ruta tiene tildes o ñ, como C:\Users\José.
        if (destino.Any(c => c > 127)) destino = @"C:\Users\Public\PetCare";
        estado.Text = "Instalando PetCare…";
        Shown += (s, e) => Trabajar(Instalar);
    }

    void Instalar()
    {
        Stream zip = Assembly.GetExecutingAssembly().GetManifestResourceStream(Programa.RECURSO);
        using (ZipArchive archivo = new ZipArchive(zip, ZipArchiveMode.Read))
        {
            string programa = Path.Combine(destino, "PetCare.exe");
            if (VersionInstalada() != VersionDe(archivo))
            {
                if (EstaAbierto()) throw new Exception("Cierra la ventana de PetCare y vuelve a intentarlo.");
                Extraer(archivo);
            }
            CrearAccesoDirecto(programa);
            Process.Start(new ProcessStartInfo(programa, enPrueba ? "/sin-navegador" : "") { WorkingDirectory = destino });
        }
        EnVentana(Close);
    }

    string VersionInstalada()
    {
        string ruta = Path.Combine(destino, "version.txt");
        return File.Exists(ruta) ? File.ReadAllText(ruta).Trim() : "";
    }

    static string VersionDe(ZipArchive archivo)
    {
        using (StreamReader r = new StreamReader(archivo.GetEntry("version.txt").Open())) return r.ReadToEnd().Trim();
    }

    static bool EstaAbierto()
    {
        Mutex m;
        if (!Mutex.TryOpenExisting("PetCare_abierto", out m)) return false;
        m.Dispose();
        return true;
    }

    void Extraer(ZipArchive archivo)
    {
        // Una versión anterior se reemplaza, pero sus datos (datos, fotos y claves) se quedan.
        string compilado = Path.Combine(destino, "app", ".next");
        if (Directory.Exists(compilado)) Directory.Delete(compilado, true);

        EnVentana(() => { barra.Style = ProgressBarStyle.Continuous; barra.Maximum = archivo.Entries.Count; });
        int hechos = 0;
        foreach (ZipArchiveEntry entrada in archivo.Entries)
        {
            string ruta = Path.Combine(destino, entrada.FullName.Replace('/', '\\'));
            if (entrada.FullName.EndsWith("/") || entrada.FullName.EndsWith("\\")) Directory.CreateDirectory(ruta);
            else
            {
                Directory.CreateDirectory(Path.GetDirectoryName(ruta));
                entrada.ExtractToFile(ruta, true);
            }
            int n = ++hechos;
            if (n % 50 == 0) EnVentana(() => barra.Value = n);
        }
    }

    void CrearAccesoDirecto(string programa)
    {
        string escritorio = enPrueba ? destino : Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic acceso = shell.CreateShortcut(Path.Combine(escritorio, "PetCare.lnk"));
        acceso.TargetPath = programa;
        acceso.WorkingDirectory = destino;
        acceso.IconLocation = programa + ",0";
        acceso.Description = "Abrir PetCare";
        acceso.Save();
    }
}

class VentanaPrincipal : VentanaBase
{
    readonly string carpeta;
    readonly bool abrirNavegador;
    readonly Label acceso = new Label();
    readonly Button abrir = new Button();
    readonly Button cerrar = new Button();
    Process servidor;
    string puerto;
    volatile bool saliendo;

    string Postgres(string programa) { return Path.Combine(carpeta, "postgres", "bin", programa); }
    string EnCarpeta(string archivo) { return Path.Combine(carpeta, archivo); }

    public VentanaPrincipal(string carpetaInstalada, bool conNavegador) : base(300)
    {
        carpeta = carpetaInstalada;
        abrirNavegador = conNavegador;

        acceso.Location = new Point(26, 118);
        acceso.Size = new Size(410, 120);
        acceso.Visible = false;
        Controls.Add(acceso);

        abrir.Text = "Abrir PetCare";
        abrir.Location = new Point(26, 250);
        abrir.Size = new Size(195, 34);
        abrir.Enabled = false;
        abrir.Click += (s, e) => Programa.AbrirNavegador(puerto);
        Controls.Add(abrir);

        cerrar.Text = "Cerrar PetCare";
        cerrar.Location = new Point(239, 250);
        cerrar.Size = new Size(195, 34);
        cerrar.Click += (s, e) => Close();
        Controls.Add(cerrar);

        estado.Text = "Abriendo PetCare…";
        Shown += (s, e) => Trabajar(Arrancar);
        FormClosing += (s, e) => { Hide(); Detener(); };
    }

    void Arrancar()
    {
        DetenerServidorHuerfano();
        Environment.SetEnvironmentVariable("PGHOST", "127.0.0.1");
        Environment.SetEnvironmentVariable("PGUSER", "postgres");
        Environment.SetEnvironmentVariable("PGDATABASE", "petcare");
        Environment.SetEnvironmentVariable("PGCLIENTENCODING", "UTF8");
        Environment.SetEnvironmentVariable("TZ", "America/Bogota");
        Environment.SetEnvironmentVariable("NODE_ENV", "production");
        Environment.SetEnvironmentVariable("HOSTNAME", "127.0.0.1");
        CargarClaves();

        if (File.Exists(EnCarpeta("listo.txt"))) ArrancarBase();
        else PrepararPrimeraVez();

        Mensaje("Abriendo la página…");
        ArrancarPagina();
        EsperarPagina();
        File.WriteAllText(EnCarpeta("puerto.txt"), puerto);

        string clave = File.ReadAllText(EnCarpeta("clave-demo.txt")).Trim();
        EnVentana(() =>
        {
            barra.Visible = false;
            estado.Text = "PetCare ya está abierto en tu navegador. Deja esta ventana abierta mientras lo usas y ciérrala cuando termines.";
            acceso.Text = "Para entrar al panel, en el menú elige «Acceso»:\n\n"
                + "   Administrador:  vsandoval\n"
                + "   Veterinario:  lferreyra\n"
                + "   Recepción:  cruiz\n"
                + "   Contraseña de los tres:  " + clave;
            acceso.Visible = true;
            abrir.Enabled = true;
        });
        if (abrirNavegador) Programa.AbrirNavegador(puerto);
    }

    /** Claves propias de cada instalación: se crean una vez y no salen de este computador. */
    void CargarClaves()
    {
        string ruta = EnCarpeta("ajustes.txt");
        if (!File.Exists(ruta)) File.WriteAllLines(ruta, new[] { Aleatorio(), Aleatorio() });
        string[] lineas = File.ReadAllLines(ruta);
        Environment.SetEnvironmentVariable("PGPASSWORD", lineas[0]);
        Environment.SetEnvironmentVariable("AUTH_SECRET", lineas[1]);
    }

    static string Aleatorio()
    {
        byte[] b = new byte[32];
        using (RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider()) rng.GetBytes(b);
        return BitConverter.ToString(b).Replace("-", "").ToLowerInvariant();
    }

    void PrepararPrimeraVez()
    {
        Mensaje("Preparando PetCare por primera vez. Puede tardar un par de minutos…");
        // Si una primera vez quedó a medias, se empieza de cero: aún no hay nada que perder.
        if (Directory.Exists(EnCarpeta("datos"))) Directory.Delete(EnCarpeta("datos"), true);

        string temporal = EnCarpeta("clave.tmp");
        File.WriteAllText(temporal, Environment.GetEnvironmentVariable("PGPASSWORD"));
        try
        {
            Exigir(Correr(Postgres("initdb.exe"), "-D datos -U postgres -A scram-sha-256 --pwfile=clave.tmp -E UTF8 --locale=C --locale-provider=icu --icu-locale=es-CO", true), "crear la base");
        }
        finally { File.Delete(temporal); }

        ArrancarBase();
        Exigir(Correr(Postgres("psql.exe"), "-w -d postgres -q -c \"CREATE DATABASE petcare\"", true), "crear la base");
        Exigir(Correr(Postgres("psql.exe"), "-w -d petcare -q -v ON_ERROR_STOP=1 -f petcare.sql -o NUL", true), "cargar los datos");
        File.WriteAllText(EnCarpeta("listo.txt"), "ok");
    }

    void ArrancarBase()
    {
        if (Correr(Postgres("pg_ctl.exe"), "-D datos status", false) == 0)
        {
            // Quedó abierta de antes: su puerto está en la cuarta línea de postmaster.pid.
            Environment.SetEnvironmentVariable("PGPORT", File.ReadLines(EnCarpeta("datos\\postmaster.pid")).ElementAt(3).Trim());
            return;
        }
        string p = PuertoLibre(55432);
        Environment.SetEnvironmentVariable("PGPORT", p);
        // Solo escucha en este computador: nadie más de la red puede llegar a la base.
        Exigir(Correr(Postgres("pg_ctl.exe"), "-D datos -w -t 90 -l pg.log -o \"-p " + p + " -c listen_addresses=127.0.0.1 -c timezone=America/Bogota\" start", false), "arrancar la base");
    }

    void ArrancarPagina()
    {
        puerto = PuertoLibre(47100);
        Environment.SetEnvironmentVariable("PORT", puerto);
        ProcessStartInfo info = new ProcessStartInfo(EnCarpeta("app\\node.exe"), "server.js")
        {
            WorkingDirectory = EnCarpeta("app"),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        servidor = Process.Start(info);
        servidor.OutputDataReceived += (s, e) => Registrar(e.Data);
        servidor.ErrorDataReceived += (s, e) => Registrar(e.Data);
        servidor.BeginOutputReadLine();
        servidor.BeginErrorReadLine();
    }

    void EsperarPagina()
    {
        // /agendar consulta la base: si responde, la página y la base funcionan.
        for (int i = 0; i < 90; i++)
        {
            if (saliendo) return;
            if (servidor.HasExited) throw new Exception("La página se cerró sola. Revisa registro.txt en " + carpeta);
            try
            {
                HttpWebRequest pedido = (HttpWebRequest)WebRequest.Create("http://127.0.0.1:" + puerto + "/agendar");
                pedido.Proxy = null;
                pedido.Timeout = 5000;
                using (HttpWebResponse r = (HttpWebResponse)pedido.GetResponse())
                    if (r.StatusCode == HttpStatusCode.OK) return;
            }
            catch (WebException) { }
            Thread.Sleep(1000);
        }
        throw new Exception("La página tardó demasiado en abrir. Revisa registro.txt en " + carpeta);
    }

    int Correr(string programa, string argumentos, bool registrar)
    {
        // pg_ctl no se redirige: la base hereda sus salidas y la espera no terminaría nunca.
        ProcessStartInfo info = new ProcessStartInfo(programa, argumentos)
        {
            WorkingDirectory = carpeta,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = registrar,
            RedirectStandardError = registrar,
        };
        using (Process p = new Process { StartInfo = info })
        {
            if (registrar)
            {
                p.OutputDataReceived += (s, e) => Registrar(e.Data);
                p.ErrorDataReceived += (s, e) => Registrar(e.Data);
            }
            p.Start();
            if (registrar) { p.BeginOutputReadLine(); p.BeginErrorReadLine(); }
            p.WaitForExit();
            return p.ExitCode;
        }
    }

    void Exigir(int codigo, string paso)
    {
        if (codigo != 0) throw new Exception("Falló al " + paso + ". Revisa registro.txt y pg.log en " + carpeta);
    }

    readonly object candado = new object();
    void Registrar(string linea)
    {
        if (linea == null) return;
        lock (candado) File.AppendAllText(EnCarpeta("registro.txt"), linea + Environment.NewLine);
    }

    static string PuertoLibre(int desde)
    {
        for (int p = desde; p < desde + 100; p++)
        {
            try
            {
                TcpListener prueba = new TcpListener(IPAddress.Loopback, p);
                prueba.Start();
                prueba.Stop();
                return p.ToString();
            }
            catch (SocketException) { }
        }
        throw new Exception("No hay puertos libres en este computador.");
    }

    /** Si Windows cerró PetCare de golpe, su página pudo quedar corriendo sin ventana. */
    void DetenerServidorHuerfano()
    {
        string nuestro = EnCarpeta("app\\node.exe");
        foreach (Process p in Process.GetProcessesByName("node"))
        {
            try
            {
                if (string.Equals(p.MainModule.FileName, nuestro, StringComparison.OrdinalIgnoreCase)) p.Kill();
            }
            catch (Exception) { }
        }
    }

    void Detener()
    {
        saliendo = true;
        try { if (servidor != null && !servidor.HasExited) servidor.Kill(); } catch (Exception) { }
        try { Correr(Postgres("pg_ctl.exe"), "-D datos -w -t 30 -m fast stop", false); } catch (Exception) { }
        try { File.Delete(EnCarpeta("puerto.txt")); } catch (Exception) { }
    }
}
