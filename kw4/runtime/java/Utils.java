
//Title:        Amzi! IDE
//Version:
//Copyright:    Copyright (c) 1999
//Author:       Mary
//Company:      Amzi!
//Description:

import amzi.ls.*;
import java.util.*;
import com.borland.jb.util.*;

public class Utils
{
   public static Properties prologListToProperties(LogicServer ls, long list, int size) throws LSException
   {
      Properties p = new Properties();
      long element, name, value;

      // Check for the empty list or an atom
      long type = ls.GetTermType(list);
      if (type != LogicServer.pLIST) return p;

      // Otherwise get the head
      element = ls.GetHead(list);
      name = ls.GetArg(element, 1);
      value = ls.GetArg(element, 2);
      if (ls.GetTermType(value) == LogicServer.pLIST)
         p.setProperty(ls.TermToStr(name, size), ls.TermToStrQ(value, size));
      else
         p.setProperty(ls.TermToStr(name, size), ls.TermToStr(value, size));

      // And the rest of the list
      list = ls.GetTail(list);
      while (list != 0)
      {
         element = ls.GetHead(list);
         name = ls.GetArg(element, 1);
         value = ls.GetArg(element, 2);
         if (ls.GetTermType(value) == LogicServer.pLIST)
            p.setProperty(ls.TermToStr(name, size), ls.TermToStrQ(value, size));
         else
            p.setProperty(ls.TermToStr(name, size), ls.TermToStr(value, size));

         list = ls.GetTail(list);
      }
      return p;
   }

   public static Properties prologListToPropertiesQ(LogicServer ls, long list, int size) throws LSException
   {
      Properties p = new Properties();
      long element, name, value;

      // Check for the empty list or an atom
      long type = ls.GetTermType(list);
      if (type != LogicServer.pLIST) return p;

      // Otherwise get the head
      element = ls.GetHead(list);
      name = ls.GetArg(element, 1);
      value = ls.GetArg(element, 2);
      p.setProperty(ls.TermToStr(name, size), ls.TermToStrQ(value, size));

      // And the rest of the list
      list = ls.GetTail(list);
      while (list != 0)
      {
         element = ls.GetHead(list);
         name = ls.GetArg(element, 1);
         value = ls.GetArg(element, 2);
         p.setProperty(ls.TermToStr(name, size), ls.TermToStrQ(value, size));

         list = ls.GetTail(list);
      }
      return p;
   }

   public static Vector prologListToVector(LogicServer ls, long list, int size) throws LSException
   {
      Vector v = new Vector();

      // Check for the empty list or an atom
      long type = ls.GetTermType(list);
      if (type != LogicServer.pLIST) return v;

      // Otherwise get the head
      v.addElement(ls.TermToStr(ls.GetHead(list), size));

      // And the rest of the list
      list = ls.GetTail(list);
      while (list != 0)
      {
         v.addElement(ls.TermToStr(ls.GetHead(list), size));

         list = ls.GetTail(list);
      }
      return v;
   }

   public static Vector prologListToVectorQ(LogicServer ls, long list, int size) throws LSException
   {
      Vector v = new Vector();

      // Check for the empty list or an atom
      long type = ls.GetTermType(list);
      if (type != LogicServer.pLIST) return v;

      // Otherwise get the head
      type = ls.GetTermType(ls.GetHead(list));
      v.addElement(ls.TermToStrQ(ls.GetHead(list), size));

      // And the rest of the list
      list = ls.GetTail(list);
      while (list != 0)
      {
         type = ls.GetTermType(ls.GetHead(list));
         v.addElement(ls.TermToStrQ(ls.GetHead(list), size));

         list = ls.GetTail(list);
      }
      return v;
   }

   public static String findClasspathFile(String fileName, String relDir)
   {
      SearchPath sp;

      sp = new SearchPath(System.getProperty("user.dir"), relDir);
      if (sp.getPath(fileName) != null)
         return sp.getPath(fileName);

      sp = new SearchPath(System.getProperty("java.class.path"), relDir);
         return sp.getPath(fileName);

   }

   public static String doubleSlashes(String s)
   {
      String slashed;
      int i, slash;

      slashed = "";
      i = 0;
      while ((slash = s.indexOf("\\", i)) >= 0)
      {
         slashed = slashed + s.substring(i, slash) + "\\\\";
         i = slash+1;
      }
      slashed = slashed + s.substring(i, s.length());
      return slashed;
   }

   public static String doubleDollars(String in)
   {
      StringBuffer sb = new StringBuffer("");
      for (int i = 0; i < in.length(); i++)
      {
         if (in.charAt(i) == '$')
            sb.append(in.charAt(i));
         sb.append(in.charAt(i));
      }
      return sb.toString();
   }

   public static String doubleQuotes(String in)
   {
      StringBuffer sb = new StringBuffer("");
      for (int i = 0; i < in.length(); i++)
      {
         if (in.charAt(i) == '\'')
            sb.append(in.charAt(i));
         sb.append(in.charAt(i));
      }
      return sb.toString();
   }

   public static String quotePathname(String pathname)
   {
      int i, j;

      if (pathname.trim().equals("/")) return "/";

      String result = "";
      i = pathname.indexOf('/');
      do
      {
         j = pathname.indexOf('/', i+1);
         if (j < 0) j = pathname.length();
         if (pathname.charAt(i+2) == '\'' && pathname.charAt(j-1) == '\'')
            result = result + "/ " + pathname.substring(i+1, j);
         else
            result = result + "/ '" + doubleQuotes(pathname.substring(i+1, j).trim()) + "'";
         i = j;
      } while (j < pathname.length());
      return result;
   }

   public static String extractPath(String pathname)
   {
      int i = pathname.lastIndexOf('/');
      if (i == 0)
         return "/";
      else
         return pathname.substring(0, i-2);
   }

   public static String extractName(String pathname)
   {
      int i = pathname.lastIndexOf('/');
      return pathname.substring(i+2, pathname.length()-1);
   }

}
